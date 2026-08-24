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

        // 다시 읽기를 고르면 창을 새로 읽어 목록을 다시 만든다. 그 사이 사용자가 창을
        // 옮겼을 수 있으므로 앞서 고른 체크와 자리는 유지하지 않는다. 목록 자체가 달라진다.
        while true {
            let captured = WorkspaceCapture.capture(name: name, displays: displays)
            guard captured.draft.itemCount > 0 else {
                Prompt.message(
                    "담을 창이 없습니다",
                    "열린 창이 없습니다. 앱을 배치한 뒤 다시 시도하세요.")
                return
            }

            switch DraftDialog.edit(
                captured.draft, title: "'\(name)'에 담을 내용",
                notes: notes(for: captured), allowsReload: true
            ) {
            case .reload:
                continue
            case .cancelled:
                return
            case .saved(let draft):
                if let reason = WorkspaceFiles.save(draft) {
                    Prompt.message("저장하지 못했습니다", reason)
                }
                return
            }
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

    /// 캡처에서 알아둘 것을 짧게 모은다. 길게 늘어놓으면 아무도 읽지 않는다.
    private static func notes(for captured: WorkspaceCapture.Result) -> [String] {
        var notes: [String] = []

        let dropped = captured.indistinguishable
        if !dropped.isEmpty {
            let total = dropped.values.reduce(0, +)
            let apps = dropped.keys.sorted().joined(separator: ", ")
            notes.append("창 \(total)개는 제목으로 구분할 수 없어 담지 않았습니다 (\(apps)).")
        }
        if !captured.browsersWithoutTabs.isEmpty {
            let apps = captured.browsersWithoutTabs.map(\.app).joined(separator: ", ")
            notes.append("\(apps)의 탭은 읽지 못해 창 위치만 담았습니다.")
        }
        return notes
    }
}
