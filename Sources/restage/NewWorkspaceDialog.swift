import AppKit
import RestageKit
import RestageKitDarwin
import SwiftUI

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

    private static func notes(for captured: WorkspaceCapture.Result) -> [String] {
        var notes: [String] = []

        let byOrder = captured.byOrder
        if !byOrder.isEmpty {
            let total = byOrder.values.reduce(0, +)
            let apps = byOrder.keys.sorted().joined(separator: ", ")
            notes.append(L10n.string("new.note.by_order_windows", total, apps))
        }
        if !captured.browsersWithoutTabs.isEmpty {
            let apps = captured.browsersWithoutTabs.map(\.app).joined(separator: ", ")
            notes.append(L10n.string("new.note.tabs_unreadable", apps))
        }
        if !captured.browsersWithoutURLs.isEmpty {
            let apps = captured.browsersWithoutURLs.joined(separator: ", ")
            notes.append(L10n.string("new.note.browser_no_urls", apps))
        }
        return notes
    }
}
