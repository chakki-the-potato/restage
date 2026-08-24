/// 초안을 config 파일 텍스트로 만든다.
///
/// Yams의 인코더를 쓰지 않는 이유는 사람이 읽고 이어서 고칠 파일이기 때문이다.
/// 항목 하나가 한 줄에 들어가는 형태와 키 순서를 직접 정해야 `examples/`와 같은 모양이 나온다.
public enum ConfigWriter {
    public static func yaml(for draft: WorkspaceDraft) -> String {
        var lines: [String] = ["workspace: \(scalar(draft.name))"]
        if let hotkey = draft.hotkey {
            lines.append("hotkey: \(scalar(hotkey))")
        }
        lines.append("screens:")

        for (index, screen) in draft.screens.enumerated() {
            if index > 0 { lines.append("") }
            lines.append("  - id: \(scalar(screen.id))")
            lines.append("    display: \(screen.display.yamlValue)")
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
            if !tabs.isEmpty {
                lines.append("        tabs:")
                lines.append(contentsOf: tabs.map { "          - \(scalar($0))" })
            }
            return lines
        }
    }

    /// YAML 스칼라로 안전한 형태를 돌려준다.
    ///
    /// 앱 이름과 창 제목은 사용자 컴퓨터에서 오는 값이라 콜론, 쉼표, 중괄호가 들어올 수 있다.
    /// 그대로 쓰면 구조가 깨지므로 평범한 문자열일 때만 따옴표를 생략한다.
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
