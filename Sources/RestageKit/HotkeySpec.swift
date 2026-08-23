import Foundation

public enum HotkeyModifier: String, Sendable, CaseIterable {
    case control
    case option
    case shift
    case command

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
                raw, reason: "수식키와 키를 + 로 이어 적으세요. 예: ctrl+alt+cmd+1")
        }

        var modifiers = Set<HotkeyModifier>()
        for part in parts.dropLast() {
            guard let modifier = HotkeyModifier.named(part) else {
                throw ConfigError.invalidHotkey(
                    raw, reason: "알 수 없는 수식키입니다: \(part). 가능한 값: cmd, ctrl, alt, shift")
            }
            modifiers.insert(modifier)
        }

        guard isValidKey(key) else {
            throw ConfigError.invalidHotkey(
                raw, reason: "알 수 없는 키입니다: \(key). 가능한 값: 0-9, a-z, f1-f12, space, return, tab, escape")
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
