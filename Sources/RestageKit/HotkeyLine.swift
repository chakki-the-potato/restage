import Foundation

public enum HotkeyLine {
    private static let key = "hotkey:"
    private static let anchor = "workspace:"

    public static func apply(_ hotkey: String?, to yaml: String) -> String {
        var lines = yaml.components(separatedBy: "\n")

        if let index = lines.firstIndex(where: { isHotkey($0) }) {
            guard let hotkey else {
                lines.remove(at: index)
                return lines.joined(separator: "\n")
            }
            lines[index] = line(for: hotkey)
            return lines.joined(separator: "\n")
        }

        guard let hotkey else { return yaml }
        let insertion = lines.firstIndex { $0.hasPrefix(anchor) }.map { $0 + 1 } ?? 0
        lines.insert(line(for: hotkey), at: insertion)
        return lines.joined(separator: "\n")
    }

    private static func isHotkey(_ line: String) -> Bool {
        line.hasPrefix(key)
    }

    private static func line(for hotkey: String) -> String {
        "\(key) \"\(hotkey)\""
    }
}
