import RestageKit

enum DraftSummary {
    static var uncertaintyNote: String { L10n.string("draft.uncertainty_note") }

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
