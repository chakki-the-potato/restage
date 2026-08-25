import RestageKit

enum LayoutSummaryLabel {
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
