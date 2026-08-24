import Foundation

public enum HotkeyModifier: String, Sendable, CaseIterable {
    case control
    case option
    case shift
    case command

    /// config 파일에 적는 이름. `HotkeyModifier.named`가 받아들이는 값이어야 한다.
    public var configName: String {
        switch self {
        case .control: return "ctrl"
        case .option: return "alt"
        case .shift: return "shift"
        case .command: return "cmd"
        }
    }

    /// macOS 관례 표기. 메뉴에 보여줄 때 이 순서로 나열한다.
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

/// `"ctrl+alt+cmd+1"` 같은 문자열을 OS에 의존하지 않는 형태로 표현한다.
///
/// Carbon 상수는 `restage` 타겟의 `HotkeyRegistry`에만 존재한다. 여기서는 키를
/// 정규화된 이름으로만 다뤄 파싱을 순수 함수로 유지하고 단위 테스트가 가능하게 한다.
public struct HotkeySpec: Equatable, Sendable {
    public let modifiers: Set<HotkeyModifier>
    /// 정규화된 키 이름. "1", "a", "f1", "space" 등.
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

    /// 메뉴에 표시할 기호 문자열. 수식키는 macOS 관례 순서로 정렬한다.
    public var displayString: String {
        let symbols = HotkeyModifier.allCases
            .filter { modifiers.contains($0) }
            .map(\.symbol)
            .joined()
        return symbols + key.uppercased()
    }

    /// config 파일에 적는 문자열. `parse`의 역이다.
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

    /// 수식키 없는 조합은 받지 않는다. 전역 단축키로 등록하면 평범한 타자를 가로챈다.
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
