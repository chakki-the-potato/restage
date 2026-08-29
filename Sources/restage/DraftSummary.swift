import RestageKit

enum DraftSummary {
    static var uncertaintyNote: String { L10n.string("draft.uncertainty_note") }

    static func lines(_ draft: WorkspaceDraft, numbered: Bool) -> [String] {
        var lines: [String] = []
        for entry in DraftSelection.entries(in: draft) {
            if entry.startsScreen { lines.append("  \(entry.screenID)") }
            let prefix = numbered ? "   \(String(format: "%2d", entry.index + 1)). " : "     "
            lines.append(prefix + describe(entry))
        }
        return lines
    }

    static func hasUncertainItem(_ draft: WorkspaceDraft) -> Bool {
        draft.screens.contains { $0.items.contains { !$0.isConfident } }
    }

    private static func describe(_ entry: DraftSelection.Entry) -> String {
        let item = entry.item
        let slot = item.slot.map(SlotLabel.text) ?? L10n.string("placement.keep_size")
        let marker = item.isConfident ? " " : "?"
        let label = DraftSelection.label(for: entry, titleLimit: 18)
        var text = label.padded(to: 30) + slot + marker
        if item.isBrowser {
            text += "  " + (item.tabs.isEmpty
                ? L10n.string("summary.no_tabs")
                : L10n.string("summary.tabs", item.tabs.count))
        }
        if !item.wasOnCurrentSpace {
            text += "  " + L10n.string("summary.other_desktop")
        }
        return text
    }
}
