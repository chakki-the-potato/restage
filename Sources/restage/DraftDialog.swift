import AppKit
import RestageKit
import SwiftUI

/// 초안을 보여주고 고쳐 돌려주는 창.
///
/// 새로 만들 때와 기존 것을 고칠 때 같은 창을 쓴다. 둘의 차이는 초안이 어디서 왔는지뿐이다.
@MainActor
enum DraftDialog {
    enum Outcome {
        case saved(WorkspaceDraft)
        /// 창 배치를 다시 읽어 목록을 새로 만든다.
        case reload
        case cancelled
    }

    /// 목록을 보여주기 전에 창 배치를 읽어야 하므로, 저장을 누른 순간이 아니라 목록을
    /// 만든 순간의 배치가 담긴다. 그 사이에 창을 옮겼다면 `다시 읽기`로 새로 읽는다.
    ///
    /// - Parameter allowsReload: 캡처에서 온 초안일 때만 true. 저장된 config를 편집할
    ///   때는 다시 읽을 원본이 창이 아니라 파일이라 의미가 없다.
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
