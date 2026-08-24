import RestageKit

/// 배치 모양을 목록에 보일 한 줄로 바꾼다.
///
/// `LayoutShape` 옆이 아니라 여기 두는 이유는 `SlotLabel`과 같다. 판정은 config를 읽는
/// 일이고 문구는 화면에만 쓰인다.
enum LayoutSummaryLabel {
    /// 화면이 하나면 배치만 적는다. 여러 대일 때만 몇 대인지 덧붙인다.
    static func text(_ summary: WorkspaceSummary) -> String {
        let shape = text(summary.shape)
        guard summary.screenCount > 1 else { return shape }
        return L10n.string(
            "layout.summary", shape, L10n.string("layout.displays", summary.screenCount))
    }

    static func text(_ shape: LayoutShape) -> String {
        switch shape {
        case .fullScreen: return L10n.string("layout.full_screen")
        case .single(let slot): return SlotLabel.text(slot)
        case .leftRight: return L10n.string("layout.left_right")
        case .topBottom: return L10n.string("layout.top_bottom")
        case .quarters: return L10n.string("layout.quarters")
        case .panes(let count): return L10n.string("layout.panes", count)
        case .mixed: return L10n.string("layout.mixed")
        }
    }
}
