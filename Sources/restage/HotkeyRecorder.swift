import AppKit
import RestageKit

@MainActor
enum HotkeyRecorder {
    enum Outcome {
        case set(HotkeySpec)
        case cleared
        case cancelled
    }

    private static let namedKeys: [UInt16: String] = [
        49: "space", 36: "return", 48: "tab",
        122: "f1", 120: "f2", 99: "f3", 118: "f4", 96: "f5", 97: "f6",
        98: "f7", 100: "f8", 101: "f9", 109: "f10", 103: "f11", 111: "f12",
    ]

    static func record(workspace: String, current: HotkeySpec?) -> Outcome {
        let alert = NSAlert()
        alert.messageText = L10n.string("hotkey.title", workspace)
        alert.informativeText =
            L10n.string("hotkey.instructions")
        let save = alert.addButton(withTitle: L10n.string("common.save"))
        alert.addButton(withTitle: L10n.string("common.clear"))
        alert.addButton(withTitle: L10n.string("common.cancel"))

        let display = NSTextField(labelWithString: current?.displayString ?? L10n.string("hotkey.press_keys"))
        display.font = .systemFont(ofSize: 20, weight: .medium)
        display.alignment = .center
        display.frame = NSRect(x: 0, y: 0, width: 260, height: 34)
        alert.accessoryView = display

        var captured = current
        save.isEnabled = current != nil

        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode != 53 else { return event }
            guard let spec = spec(from: event) else {
                display.stringValue = L10n.string("hotkey.needs_modifier")
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

    private static func keyName(for event: NSEvent) -> String? {
        if let named = namedKeys[event.keyCode] { return named }
        guard let characters = event.charactersIgnoringModifiers?.lowercased(),
              let character = characters.first,
              character.isLetter || character.isNumber else { return nil }
        return String(character)
    }
}
