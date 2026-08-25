import Foundation

public enum HotkeyModifier: String, Sendable, CaseIterable {
    case control
    case option
    case shift
    case command

    public var configName: String {
        switch self {
        case .control: return "ctrl"
        case .option: return "alt"
        case .shift: return "shift"
        case .command: return "cmd"
        }
    }

    public var symbol: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        }
    }

    static func named(_ raw: String) -> HotkeyModifier? {
        switch raw {
        case "cmd", "command": return .command
        case "ctrl", "control": return .control
        case "alt", "opt", "option": return .option
        case "shift": return .shift
        default: return nil
        }
    }
}

public struct HotkeySpec: Equatable, Sendable {
    public let modifiers: Set<HotkeyModifier>
    public let key: String

    private static let namedKeys: Set<String> = ["space", "return", "tab", "escape"]

    public static func parse(_ raw: String) throws -> HotkeySpec {
        let parts = raw.split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        guard let key = parts.last, parts.count >= 2 else {
            throw ConfigError.invalidHotkey(
                raw, reason: L10n.string("error.hotkey.format"))
        }

        var modifiers = Set<HotkeyModifier>()
        for part in parts.dropLast() {
            guard let modifier = HotkeyModifier.named(part) else {
                throw ConfigError.invalidHotkey(
                    raw, reason: L10n.string("error.hotkey.unknown_modifier", part))
            }
            modifiers.insert(modifier)
        }

        guard isValidKey(key) else {
            throw ConfigError.invalidHotkey(
                raw, reason: L10n.string("error.hotkey.unknown_key", key))
        }

        return HotkeySpec(modifiers: modifiers, key: key)
    }

    public var displayString: String {
        let symbols = HotkeyModifier.allCases
            .filter { modifiers.contains($0) }
            .map(\.symbol)
            .joined()
        return symbols + key.uppercased()
    }

    public var configString: String {
        let names = HotkeyModifier.allCases
            .filter { modifiers.contains($0) }
            .map(\.configName)
        return (names + [key]).joined(separator: "+")
    }

    public init(modifiers: Set<HotkeyModifier>, key: String) {
        self.modifiers = modifiers
        self.key = key
    }

    public var isUsableAsGlobalHotkey: Bool {
        !modifiers.isEmpty && Self.isValidKey(key)
    }

    private static func isValidKey(_ key: String) -> Bool {
        if namedKeys.contains(key) { return true }
        if key.count == 1, let character = key.first {
            return character.isLetter || character.isNumber
        }
        if key.hasPrefix("f"), let number = Int(key.dropFirst()) {
            return (1...12).contains(number)
        }
        return false
    }
}
