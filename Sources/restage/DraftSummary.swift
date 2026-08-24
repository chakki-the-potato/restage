import RestageKit

/// 워크스페이스 초안을 사람이 읽는 목록으로 만든다.
///
/// 터미널의 `restage new`와 메뉴바의 새로 만들기 창이 같은 내용을 보여줘야 하므로 한곳에 둔다.
/// 번호는 터미널에서만 쓴다. 창에서는 고를 수 없으니 붙이면 눌러도 되는 것처럼 보인다.
enum DraftSummary {
    static var uncertaintyNote: String { L10n.string("draft.uncertainty_note") }

    /// 화면 이름과 그 아래 항목들. 빈 초안이면 빈 배열이다.
    static func lines(_ draft: WorkspaceDraft, numbered: Bool) -> [String] {
        var lines: [String] = []
        var number = 0

        for screen in draft.screens {
            lines.append("  \(screen.id)")
            for item in screen.items {
                number += 1
                let prefix = numbered ? "   \(String(format: "%2d", number)). " : "     "
                lines.append(prefix + describe(item))
            }
        }
        return lines
    }

    static func hasUncertainItem(_ draft: WorkspaceDraft) -> Bool {
        draft.screens.contains { $0.items.contains { !$0.isConfident } }
    }

    private static func describe(_ item: ItemDraft) -> String {
        let slot = item.slot.map(SlotLabel.text) ?? L10n.string("placement.keep_size")
        let marker = item.isConfident ? " " : "?"
        var text = label(for: item).padded(to: 30) + slot + marker
        if case .browser(let urls) = item.kind, !urls.isEmpty {
            text += "  " + L10n.string("summary.tabs", urls.count)
        }
        if !item.wasOnCurrentSpace {
            text += "  " + L10n.string("summary.other_desktop")
        }
        return text
    }

    /// 같은 앱의 창이 여럿이면 제목을 붙여 구분한다.
    private static func label(for item: ItemDraft) -> String {
        guard let title = item.titleHint, !title.isEmpty else { return item.app }
        return "\(item.app) · \(trimmed(title))"
    }

    private static let titleLimit = 18

    private static func trimmed(_ title: String) -> String {
        guard title.count > titleLimit else { return title }
        return String(title.prefix(titleLimit)) + "…"
    }
}
