import AppKit
import RestageKit

/// 키 조합을 눌러 단축키를 정한다.
///
/// 텍스트로 적게 하지 않는 이유는 `ctrl+alt+cmd+1` 같은 표기를 외워야 하고 오타가 나기
/// 때문이다. 누른 것을 그대로 받는 편이 짧고 틀릴 수 없다.
@MainActor
enum HotkeyRecorder {
    enum Outcome {
        case set(HotkeySpec)
        case cleared
        case cancelled
    }

    /// 이름이 있는 키. 나머지는 눌린 문자를 그대로 쓴다.
    private static let namedKeys: [UInt16: String] = [
        49: "space", 36: "return", 48: "tab",
        122: "f1", 120: "f2", 99: "f3", 118: "f4", 96: "f5", 97: "f6",
        98: "f7", 100: "f8", 101: "f9", 109: "f10", 103: "f11", 111: "f12",
    ]

    static func record(workspace: String, current: HotkeySpec?) -> Outcome {
        let alert = NSAlert()
        alert.messageText = "'\(workspace)' 단축키"
        alert.informativeText =
            "원하는 키 조합을 누르세요. ⌘ ⌃ ⌥ ⇧ 중 하나 이상을 함께 눌러야 합니다."
        let save = alert.addButton(withTitle: "저장")
        alert.addButton(withTitle: "지우기")
        alert.addButton(withTitle: "취소")

        let display = NSTextField(labelWithString: current?.displayString ?? "키를 누르세요")
        display.font = .systemFont(ofSize: 20, weight: .medium)
        display.alignment = .center
        display.frame = NSRect(x: 0, y: 0, width: 260, height: 34)
        alert.accessoryView = display

        var captured = current
        save.isEnabled = current != nil

        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape는 대화상자를 닫는 데 쓴다. 단축키로 잡으면 나갈 방법이 없다.
            guard event.keyCode != 53 else { return event }
            guard let spec = spec(from: event) else {
                display.stringValue = "수식키를 함께 누르세요"
                return nil
            }
            captured = spec
            display.stringValue = spec.displayString
            save.isEnabled = true
            return nil
        }
        defer { if let monitor { NSEvent.removeMonitor(monitor) } }

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return captured.map(Outcome.set) ?? .cancelled
        case .alertSecondButtonReturn:
            return .cleared
        default:
            return .cancelled
        }
    }

    private static func spec(from event: NSEvent) -> HotkeySpec? {
        var modifiers = Set<HotkeyModifier>()
        let flags = event.modifierFlags
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        guard !modifiers.isEmpty else { return nil }

        guard let key = keyName(for: event) else { return nil }
        let spec = HotkeySpec(modifiers: modifiers, key: key)
        return spec.isUsableAsGlobalHotkey ? spec : nil
    }

    /// 수식키를 뺀 글자를 쓴다. `charactersIgnoringModifiers`가 아니면 ⌥1이 ¡로 들어온다.
    private static func keyName(for event: NSEvent) -> String? {
        if let named = namedKeys[event.keyCode] { return named }
        guard let characters = event.charactersIgnoringModifiers?.lowercased(),
              let character = characters.first,
              character.isLetter || character.isNumber else { return nil }
        return String(character)
    }
}
