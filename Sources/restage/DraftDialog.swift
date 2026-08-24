import AppKit
import RestageKit
import SwiftUI

/// 초안을 보여주고 고쳐 돌려주는 창.
///
/// 새로 만들 때와 기존 것을 고칠 때 같은 창을 쓴다. 둘의 차이는 초안이 어디서 왔는지뿐이다.
@MainActor
enum DraftDialog {
    /// 취소하면 nil. 담을 항목이 하나도 없으면 알린 뒤 nil.
    static func edit(_ draft: WorkspaceDraft, title: String, notes: [String]) -> WorkspaceDraft? {
        let editor = DraftEditor(draft: draft)
        let view = DraftEditorView(rows: DraftEditorView.rows(for: draft), editor: editor)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 460, height: 340)

        let accepted = Prompt.confirm(
            title: title,
            body: (["담을 창과 자리를 고르세요."] + notes).joined(separator: "\n"),
            accessory: hosting,
            confirmTitle: "저장")
        guard accepted else { return nil }

        let result = editor.result
        guard result.itemCount > 0 else {
            Prompt.message("담을 항목이 없습니다", "하나 이상 고른 뒤 저장하세요.")
            return nil
        }
        return result
    }
}
