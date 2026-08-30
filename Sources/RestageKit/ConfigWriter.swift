public enum ConfigWriter {
    public static func yaml(for draft: WorkspaceDraft) -> String {
        var lines: [String] = ["workspace: \(scalar(draft.name))"]
        if draft.hideOthers {
            lines.append("hideOthers: true")
        }
        if let hotkey = draft.hotkey {
            lines.append("hotkey: \(scalar(hotkey))")
        }
        lines.append("screens:")

        for (index, screen) in draft.screens.enumerated() {
            if index > 0 { lines.append("") }
            lines.append("  - id: \(scalar(screen.id))")
            lines.append("    display: \(screen.display.yamlValue)")
            if case .external = screen.display {
                lines.append("    whenMissing: \(MissingDisplayPolicy.fullscreen.rawValue)")
            }
            lines.append("    items:")
            lines.append(contentsOf: screen.items.flatMap(itemLines))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func itemLines(_ item: ItemDraft) -> [String] {
        switch item.kind {
        case .app(let title):
            var fields = ["type: app", "app: \(scalar(item.app))"]
            if let slot = item.slot { fields.append("slot: \(slot.rawValue)") }
            if let title { fields.append("title: \(scalar(title))") }
            if item.fullscreen { fields.append("fullscreen: true") }
            return ["      - {\(fields.joined(separator: ", "))}"]

        case .browser(let tabs):
            var lines = [
                "      - type: browser",
                "        app: \(scalar(item.app))",
            ]
            if let slot = item.slot { lines.append("        slot: \(slot.rawValue)") }
            if item.fullscreen { lines.append("        fullscreen: true") }
            if !tabs.isEmpty {
                lines.append("        tabs:")
                lines.append(contentsOf: tabs.map { "          - \(scalar($0))" })
            }
            return lines
        }
    }

    static func scalar(_ text: String) -> String {
        isPlainSafe(text) ? text : quoted(text)
    }

    private static let reservedWords: Set<String> = [
        "true", "false", "yes", "no", "on", "off", "null", "none", "~",
    ]

    private static func isPlainSafe(_ text: String) -> Bool {
        guard let first = text.first, let last = text.last else { return false }
        guard !reservedWords.contains(text.lowercased()) else { return false }
        guard Double(text) == nil else { return false }
        guard !first.isWhitespace, !last.isWhitespace else { return false }
        guard first.isLetter || first.isNumber else { return false }
        return text.allSatisfy { character in
            character.isLetter || character.isNumber || character == " "
                || character == "." || character == "_" || character == "-"
        }
    }

    private static func quoted(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}
