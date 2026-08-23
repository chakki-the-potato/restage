import AppKit
import RestageBrand
import RestageKit
import RestageKitDarwin

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength)
    private var isRunning = false
    private let hotkeys = HotkeyRegistry()
    private var registrations: [String: HotkeyRegistry.Registration] = [:]

    func start() {
        statusItem.button?.image = MenuBarIcon.image()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        if !AccessibilityPermission.isTrusted() {
            _ = AccessibilityPermission.requestIfNeeded()
        }

        hotkeys.install { [weak self] workspace in
            self?.launch(workspace)
        }
        reloadHotkeys()
    }

    /// config의 hotkey를 다시 등록한다.
    ///
    /// 메뉴는 열 때마다 다시 만들 수 있지만 단축키 등록은 프로세스 수명에 묶인 자원이라
    /// 그럴 수 없다. 메뉴를 여는 시점에 config를 다시 읽으므로 그때 함께 갱신한다.
    private func reloadHotkeys() {
        let entries = (try? WorkspaceRegistry().list()) ?? []
        let declared: [(workspace: String, raw: String)] = entries.compactMap { entry in
            guard entry.error == nil,
                  let config = try? ConfigLoader.load(path: entry.path),
                  let raw = config.hotkey else { return nil }
            return (entry.name, raw)
        }
        registrations = hotkeys.reload(declared)
    }

    /// 메뉴를 열 때마다 다시 만든다.
    ///
    /// 한 번만 만들면 config 파일을 고친 뒤 앱을 재시작해야 한다. 파일을 직접 편집하는
    /// 것도 이 도구의 편집 방식이므로 재시작이 필요하면 쓰기 어렵다.
    func menuWillOpen(_ menu: NSMenu) {
        reloadHotkeys()
        let result = Result { try WorkspaceRegistry().list() }
        let granted = AccessibilityPermission.isTrusted()

        WorkspaceMenu.build(
            into: menu,
            entries: MenuContent.entries(for: result, accessibilityGranted: granted),
            hotkeyLabel: { [weak self] in self?.hotkeyLabel(for: $0) },
            hotkeyTooltip: { [weak self] in self?.hotkeyTooltip(for: $0) },
            isBusy: isRunning,
            loginItemState: LoginItem.isSupported ? (LoginItem.isEnabled ? .on : .off) : nil,
            actions: actions)
    }

    private var actions: MenuActions {
        MenuActions(
            target: self,
            run: #selector(runWorkspace(_:)),
            edit: #selector(editWorkspace(_:)),
            rename: #selector(renameWorkspace(_:)),
            reveal: #selector(revealWorkspace(_:)),
            delete: #selector(deleteWorkspace(_:)),
            newWorkspace: #selector(createWorkspace),
            toggleLogin: #selector(toggleLoginItem),
            openConfigFolder: #selector(revealConfigFolder),
            permission: #selector(openAccessibilitySettings),
            quit: #selector(quit))
    }

    /// 등록된 단축키는 항목 오른쪽에 기호로 보여준다.
    ///
    /// `keyEquivalent`로 넣지 않는 이유는 그것이 메뉴 단축키라 실제 전역 등록과 별개이기
    /// 때문이다. 등록은 Carbon 쪽에서 이미 끝났고 여기서는 표시만 한다.
    /// `NSMenuItemBadge`는 macOS 14부터라 배포 타겟(13)에서 쓸 수 없어 제목에 덧붙인다.
    private func hotkeyLabel(for workspace: String) -> String? {
        guard case .registered(let spec) = registrations[workspace] else { return nil }
        return spec.displayString
    }

    private func hotkeyTooltip(for workspace: String) -> String? {
        switch registrations[workspace] {
        case .invalid(let reason):
            return reason
        case .conflicted(let spec):
            return "단축키 \(spec.displayString)를 등록하지 못했습니다. 다른 앱이 쓰고 있거나 중복입니다"
        case .registered, nil:
            return nil
        }
    }

    // MARK: - 동작

    private func launch(_ workspace: String) {
        guard !isRunning else { return }
        isRunning = true
        Task { @MainActor in
            defer { isRunning = false }
            await run(workspace)
        }
    }

    @objc private func runWorkspace(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        launch(name)
    }

    @objc private func editWorkspace(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        report(WorkspaceFiles.openInEditor(name), title: "편집기를 열지 못했습니다")
    }

    @objc private func revealWorkspace(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        report(WorkspaceFiles.revealInFinder(name), title: "파일을 찾지 못했습니다")
    }

    @objc private func renameWorkspace(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let typed = Prompt.text(
                title: "이름 바꾸기", body: "'\(name)'의 새 이름을 정하세요.", initial: name)
        else { return }
        report(WorkspaceFiles.rename(name, to: typed), title: "이름을 바꾸지 못했습니다")
    }

    @objc private func deleteWorkspace(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              Prompt.confirmDestructive(
                title: "'\(name)'을 삭제할까요?",
                body: "휴지통으로 보냅니다. 필요하면 거기서 되돌릴 수 있습니다.",
                confirmTitle: "삭제")
        else { return }
        report(WorkspaceFiles.moveToTrash(name), title: "삭제하지 못했습니다")
    }

    @objc private func createWorkspace() {
        NewWorkspaceDialog.run()
    }

    private func run(_ name: String) async {
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

        do {
            let path = try WorkspaceRegistry().resolve(name)
            let config = try ConfigLoader.load(path: path)
            let resolved = WorkspaceResolver.resolve(config, displays: displays)
            let outcomes = await WorkspaceRunner().run(resolved)
            if let summary = MenuContent.failureSummary(outcomes) {
                Prompt.message("'\(name)' 일부 항목이 실패했습니다", summary)
            }
        } catch {
            Prompt.message("'\(name)' 실행 실패", "\(error)")
        }
    }

    @objc private func toggleLoginItem() {
        report(LoginItem.toggle(), title: "로그인 항목 등록에 실패했습니다")
    }

    @objc private func openAccessibilitySettings() {
        _ = AccessibilityPermission.requestIfNeeded()
        guard let url = URL(string: AccessibilityPermission.settingsDeepLink) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func revealConfigFolder() {
        WorkspaceFiles.revealConfigFolder()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    /// 성공했을 때는 아무것도 띄우지 않는다. 결과가 눈앞에 보이는 것이 피드백이다.
    private func report(_ failure: String?, title: String) {
        guard let failure else { return }
        Prompt.message(title, failure)
    }
}
