import AppKit
import Carbon.HIToolbox
import RestageKit

/// 전역 단축키를 등록하고 발화를 콜백으로 전달한다.
///
/// Carbon `RegisterEventHotKey`를 쓰는 이유는 추가 권한이 필요 없기 때문이다.
/// `NSEvent.addGlobalMonitorForEvents`는 접근성 권한이 필요하고 이벤트를 소비하지 못해
/// 다른 앱에도 키가 전달된다. `CGEvent` 탭은 시스템 전체 키 입력을 가로채므로 과하다.
@MainActor
final class HotkeyRegistry {
    enum Registration {
        case registered(HotkeySpec)
        case invalid(reason: String)
        case conflicted(HotkeySpec)
    }

    private struct Entry {
        let reference: EventHotKeyRef
        let workspace: String
    }

    private static let signature: OSType = 0x7273_7467

    private var entries: [UInt32: Entry] = [:]
    private var nextID: UInt32 = 1
    private var handler: EventHandlerRef?
    private var onFire: ((String) -> Void)?

    /// 등록된 조합. 같은 조합을 두 워크스페이스가 쓰면 뒤엣것은 충돌로 처리한다.
    private var claimed: Set<String> = []

    func install(onFire: @escaping (String) -> Void) {
        self.onFire = onFire
        guard handler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return noErr }
                var id = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &id)
                let registry = Unmanaged<HotkeyRegistry>
                    .fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { registry.fire(id: id.id) }
                return noErr
            },
            1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    /// 전부 해제하고 다시 등록한다.
    ///
    /// 차이를 계산하지 않는 이유는 워크스페이스가 수십 개를 넘지 않기 때문이다.
    /// 메뉴를 열 때마다 호출되므로 config를 고치면 그 시점에 반영된다.
    @discardableResult
    func reload(_ hotkeys: [(workspace: String, raw: String)]) -> [String: Registration] {
        unregisterAll()

        var result: [String: Registration] = [:]
        for (workspace, raw) in hotkeys {
            do {
                let spec = try HotkeySpec.parse(raw)
                result[workspace] = register(spec, for: workspace)
            } catch {
                result[workspace] = .invalid(reason: "\(error)")
            }
        }
        return result
    }

    private func register(_ spec: HotkeySpec, for workspace: String) -> Registration {
        guard let keyCode = Self.virtualKeyCode(for: spec.key) else {
            return .invalid(reason: L10n.string("error.hotkey.unsupported_key", spec.key))
        }
        guard claimed.insert(spec.displayString).inserted else {
            return .conflicted(spec)
        }

        var reference: EventHotKeyRef?
        let id = EventHotKeyID(signature: Self.signature, id: nextID)
        let status = RegisterEventHotKey(
            keyCode, Self.carbonModifiers(spec.modifiers), id,
            GetApplicationEventTarget(), 0, &reference)

        guard status == noErr, let reference else {
            claimed.remove(spec.displayString)
            return .conflicted(spec)
        }

        entries[nextID] = Entry(reference: reference, workspace: workspace)
        nextID += 1
        return .registered(spec)
    }

    private func unregisterAll() {
        for entry in entries.values { UnregisterEventHotKey(entry.reference) }
        entries.removeAll()
        claimed.removeAll()
    }

    private func fire(id: UInt32) {
        guard let entry = entries[id] else { return }
        onFire?(entry.workspace)
    }

    private static func carbonModifiers(_ modifiers: Set<HotkeyModifier>) -> UInt32 {
        var mask: Int = 0
        if modifiers.contains(.command) { mask |= cmdKey }
        if modifiers.contains(.control) { mask |= controlKey }
        if modifiers.contains(.option) { mask |= optionKey }
        if modifiers.contains(.shift) { mask |= shiftKey }
        return UInt32(mask)
    }

    private static let letterKeyCodes: [String: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
        "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
        "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
        "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
        "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
        "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
    ]

    private static let digitKeyCodes: [String: Int] = [
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
        "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
        "8": kVK_ANSI_8, "9": kVK_ANSI_9,
    ]

    private static let functionKeyCodes: [String: Int] = [
        "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3, "f4": kVK_F4,
        "f5": kVK_F5, "f6": kVK_F6, "f7": kVK_F7, "f8": kVK_F8,
        "f9": kVK_F9, "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,
    ]

    private static let namedKeyCodes: [String: Int] = [
        "space": kVK_Space, "return": kVK_Return, "tab": kVK_Tab, "escape": kVK_Escape,
    ]

    private static func virtualKeyCode(for key: String) -> UInt32? {
        for table in [letterKeyCodes, digitKeyCodes, functionKeyCodes, namedKeyCodes] {
            if let code = table[key] { return UInt32(code) }
        }
        return nil
    }
}
