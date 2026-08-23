import RestageKit
import RestageKitDarwin

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

        let captured: WorkspaceCapture.Result
        do {
            captured = try WorkspaceCapture.capture(name: name, displays: displays)
        } catch {
            Prompt.message("창 목록을 읽지 못했습니다", "\(error)")
            return
        }

        guard captured.draft.itemCount > 0 else {
            Prompt.message(
                "담을 창이 없습니다",
                "현재 데스크탑에 열린 창이 없습니다. 앱을 배치한 뒤 다시 시도하세요.")
            return
        }
        guard confirm(captured, name: name) else { return }

        if let reason = WorkspaceFiles.save(captured.draft) {
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

    private static func confirm(_ captured: WorkspaceCapture.Result, name: String) -> Bool {
        var footer: [String] = []
        if DraftSummary.hasUncertainItem(captured.draft) {
            footer.append(DraftSummary.uncertaintyNote + " 저장한 뒤 편집에서 고치세요.")
        }
        for skipped in captured.browsersWithoutTabs {
            footer.append("\(skipped.app)의 탭을 읽지 못해 창 위치만 담았습니다.")
        }
        footer.append("다른 데스크탑에 있거나 전체화면인 창은 담기지 않습니다.")

        return Prompt.confirmList(
            title: "'\(name)'에 담을 내용",
            body: "창 \(captured.draft.itemCount)개를 찾았습니다.",
            lines: DraftSummary.lines(captured.draft, numbered: false),
            footer: footer.joined(separator: "\n"),
            confirmTitle: "저장")
    }
}
