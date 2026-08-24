import AppKit
import RestageKit
import RestageKitDarwin
import SwiftUI

/// 메뉴에서 새 워크스페이스를 만드는 흐름.
///
/// 터미널의 `restage new`와 달리 그 자리에서 자리를 고칠 수 없다. 창 안에 목록 편집기를
/// 만드는 비용이 크기 때문이다. 대신 애매한 항목에 물음표를 붙여 보여주고, 고치는 것은
/// 저장 뒤 편집으로 넘긴다. 정확히 고르고 싶으면 터미널 쪽이 그대로 있다.
@MainActor
enum NewWorkspaceDialog {
    static func run() {
        guard let name = askName() else { return }

        guard AccessibilityPermission.isTrusted() else {
            Prompt.message("접근성 권한이 필요합니다", AccessibilityPermission.onboardingMessage)
            return
        }
        guard !ScreenLock.isLocked() else {
            Prompt.message("화면이 잠겨 있습니다", ScreenLock.message)
            return
        }
        guard let displays = DisplayCatalog.current() else {
            Prompt.message("디스플레이 조회 실패", "디스플레이 정보를 조회할 수 없습니다")
            return
        }

        let captured = WorkspaceCapture.capture(name: name, displays: displays)
        guard captured.draft.itemCount > 0 else {
            Prompt.message(
                "담을 창이 없습니다",
                "현재 데스크탑에 열린 창이 없습니다. 앱을 배치한 뒤 다시 시도하세요.")
            return
        }
        guard let draft = confirm(captured, name: name) else { return }

        if let reason = WorkspaceFiles.save(draft) {
            Prompt.message("저장하지 못했습니다", reason)
        }
    }

    private static func askName() -> String? {
        while true {
            guard let typed = Prompt.text(
                title: "새 워크스페이스",
                body: "지금 열린 창 배치를 담습니다. 이름을 정하세요.",
                confirmTitle: "다음")
            else { return nil }

            let name = WorkspaceName.normalize(typed)
            if let reason = WorkspaceName.validate(name) {
                Prompt.message("쓸 수 없는 이름입니다", reason)
                continue
            }
            if WorkspaceFiles.exists(name) {
                guard Prompt.confirmDestructive(
                    title: "'\(name)'이 이미 있습니다",
                    body: "덮어쓰면 기존 내용은 사라집니다.",
                    confirmTitle: "덮어쓰기")
                else { continue }
            }
            return name
        }
    }

    /// 담을 항목을 고르게 하고, 고른 것만 남긴 초안을 돌려준다. 취소하면 nil이다.
    private static func confirm(
        _ captured: WorkspaceCapture.Result, name: String
    ) -> WorkspaceDraft? {
        let selection = CaptureSelection(total: captured.draft.itemCount)
        let view = CaptureSelectionView(
            rows: CaptureSelectionView.rows(for: captured.draft), selection: selection)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 380, height: 260)

        var notes: [String] = []
        for skipped in captured.browsersWithoutTabs {
            notes.append("\(skipped.app)의 탭을 읽지 못해 창 위치만 담았습니다.")
        }
        if captured.onOtherSpaceCount > 0 {
            notes.append(
                "다른 데스크탑에 있는 창은 앱이 꺼진 상태에서 실행하면 정상 배치되고, "
                + "이미 떠 있으면 그 항목만 실패합니다.")
        }

        let accepted = Prompt.confirm(
            title: "'\(name)'에 담을 내용",
            body: (["담을 창을 고르세요."] + notes).joined(separator: "\n"),
            accessory: hosting,
            confirmTitle: "저장")
        guard accepted else { return nil }

        let draft = CaptureSelectionView.apply(selection.excluded, to: captured.draft)
        guard draft.itemCount > 0 else {
            Prompt.message("담을 항목이 없습니다", "하나 이상 고른 뒤 저장하세요.")
            return nil
        }
        return draft
    }
}
