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
            Prompt.message(
                L10n.string("panel.permission.title"),
                AccessibilityPermission.onboardingMessage)
            return
        }
        guard !ScreenLock.isLocked() else {
            Prompt.message(L10n.string("new.screen_locked"), ScreenLock.message)
            return
        }
        guard let displays = DisplayCatalog.current() else {
            Prompt.message(
                L10n.string("new.display_failed"),
                L10n.string("error.display.unavailable"))
            return
        }

        // 다시 읽기를 고르면 창을 새로 읽어 목록을 다시 만든다. 그 사이 사용자가 창을
        // 옮겼을 수 있으므로 앞서 고른 체크와 자리는 유지하지 않는다. 목록 자체가 달라진다.
        while true {
            let captured = WorkspaceCapture.capture(name: name, displays: displays)
            guard captured.draft.itemCount > 0 else {
                Prompt.message(
                    L10n.string("new.no_windows.title"),
                    L10n.string("new.no_windows.body"))
                return
            }

            switch DraftDialog.edit(
                captured.draft, title: L10n.string("new.contents_title", name),
                notes: notes(for: captured), allowsReload: true
            ) {
            case .reload:
                continue
            case .cancelled:
                return
            case .saved(let draft):
                if let reason = WorkspaceFiles.save(draft) {
                    Prompt.message(L10n.string("new.save_failed"), reason)
                }
                return
            }
        }
    }

    private static func askName() -> String? {
        while true {
            guard let typed = Prompt.text(
                title: L10n.string("new.title"),
                body: L10n.string("new.body"),
                confirmTitle: L10n.string("common.next"))
            else { return nil }

            let name = WorkspaceName.normalize(typed)
            if let reason = WorkspaceName.validate(name) {
                Prompt.message(L10n.string("new.bad_name"), reason)
                continue
            }
            if WorkspaceFiles.exists(name) {
                guard Prompt.confirmDestructive(
                    title: L10n.string("new.exists.title", name),
                    body: L10n.string("new.exists.body"),
                    confirmTitle: L10n.string("new.exists.confirm"))
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
            notes.append(L10n.string("new.note.ambiguous_windows", total, apps))
        }
        if !captured.browsersWithoutTabs.isEmpty {
            let apps = captured.browsersWithoutTabs.map(\.app).joined(separator: ", ")
            notes.append(L10n.string("new.note.tabs_unreadable", apps))
        }
        return notes
    }
}
