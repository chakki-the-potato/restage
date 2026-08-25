import AppKit
import RestageKit
import SwiftUI

@MainActor
enum DraftDialog {
    enum Outcome {
        case saved(WorkspaceDraft)
        case reload
        case cancelled
    }

    static func edit(
        _ draft: WorkspaceDraft, title: String, notes: [String], allowsReload: Bool = false
    ) -> Outcome {
        let editor = DraftEditor(draft: draft)
        let view = DraftEditorView(rows: DraftEditorView.rows(for: draft), editor: editor)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 460, height: 340)

        var lines = [L10n.string("draft.pick_windows")]
        if allowsReload {
            lines.append(L10n.string("draft.stale_note"))
        }

        switch Prompt.confirm(
            title: title,
            body: (lines + notes).joined(separator: "\n"),
            accessory: hosting,
            confirmTitle: L10n.string("common.save"),
            alternateTitle: allowsReload ? L10n.string("draft.reload") : nil
        ) {
        case .alternate:
            return .reload
        case .cancelled:
            return .cancelled
        case .confirmed:
            let result = editor.result
            guard result.itemCount > 0 else {
                Prompt.message(
                    L10n.string("draft.nothing_selected.title"),
                    L10n.string("draft.nothing_selected.body"))
                return .cancelled
            }
            return .saved(result)
        }
    }
}
