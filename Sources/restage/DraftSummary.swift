import RestageKit

/// 워크스페이스 초안을 사람이 읽는 목록으로 만든다.
///
/// 터미널의 `restage new`와 메뉴바의 새로 만들기 창이 같은 내용을 보여줘야 하므로 한곳에 둔다.
/// 번호는 터미널에서만 쓴다. 창에서는 고를 수 없으니 붙이면 눌러도 되는 것처럼 보인다.
enum DraftSummary {
    static let uncertaintyNote = "? 는 자리가 애매하다는 뜻입니다."

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
        let slot = item.slot.map(SlotLabel.text) ?? "크기 유지"
        let marker = item.isConfident ? " " : "?"
        var text = item.app.padded(to: 22) + slot + marker
        if case .browser(let urls) = item.kind, !urls.isEmpty {
            text += "  탭 \(urls.count)개"
        }
        return text
    }
}
