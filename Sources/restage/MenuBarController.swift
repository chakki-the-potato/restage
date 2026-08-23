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
    /// 것이 이 도구의 편집 방식이므로 재시작이 필요하면 쓰기 어렵다.
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()
        reloadHotkeys()

        let result = Result { try WorkspaceRegistry().list() }
        let granted = AccessibilityPermission.isTrusted()
        for entry in MenuContent.entries(for: result, accessibilityGranted: granted) {
            let action = entry == .permissionNeeded
                ? #selector(openAccessibilitySettings) : #selector(openWorkspace(_:))
            let item = NSMenuItem(title: entry.title, action: action, keyEquivalent: "")
            item.isEnabled = entry.isEnabled && !isRunning
            item.toolTip = entry.tooltip
            item.target = entry.isEnabled ? self : nil
            if case .workspace(let name) = entry {
                item.representedObject = name
                applyHotkey(to: item, workspace: name)
            }
            menu.addItem(item)
        }

        menu.addItem(.separator())
        if LoginItem.isSupported {
            let login = NSMenuItem(
                title: "로그인 시 자동 실행", action: #selector(toggleLoginItem), keyEquivalent: "")
            login.target = self
            login.state = LoginItem.isEnabled ? .on : .off
            menu.addItem(login)
        }
        addAction(to: menu, title: "config 폴더 열기", selector: #selector(revealConfigFolder))
        addAction(to: menu, title: "종료", selector: #selector(quit), keyEquivalent: "q")
    }

    /// 등록된 단축키는 항목 오른쪽에 기호로 보여주고, 실패한 것은 사유를 툴팁에 붙인다.
    ///
    /// `keyEquivalent`로 넣지 않는 이유는 그것이 메뉴 단축키라 실제 전역 등록과 별개이기
    /// 때문이다. 등록은 Carbon 쪽에서 이미 끝났고 여기서는 표시만 한다.
    /// `NSMenuItemBadge`는 macOS 14부터라 배포 타겟(13)에서 쓸 수 없어 제목에 덧붙인다.
    private func applyHotkey(to item: NSMenuItem, workspace: String) {
        switch registrations[workspace] {
        case .registered(let spec):
            item.title = "\(item.title)   \(spec.displayString)"
        case .invalid(let reason):
            item.toolTip = reason
        case .conflicted(let spec):
            item.toolTip = "단축키 \(spec.displayString)를 등록하지 못했습니다. 다른 앱이 쓰고 있거나 중복입니다"
        case nil:
            break
        }
    }

    private func launch(_ workspace: String) {
        guard !isRunning else { return }
        isRunning = true
        Task { @MainActor in
            defer { isRunning = false }
            await run(workspace)
        }
    }

    private func addAction(
        to menu: NSMenu, title: String, selector: Selector, keyEquivalent: String = ""
    ) {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: keyEquivalent)
        item.target = self
        menu.addItem(item)
    }

    @objc private func openWorkspace(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String, !isRunning else { return }
        isRunning = true
        Task { @MainActor in
            defer { isRunning = false }
            await run(name)
        }
    }

    private func run(_ name: String) async {
        guard AccessibilityPermission.isTrusted() else {
            alert("접근성 권한이 필요합니다", AccessibilityPermission.onboardingMessage)
            return
        }
        guard !ScreenLock.isLocked() else {
            alert("화면이 잠겨 있습니다", ScreenLock.message)
            return
        }
        guard let displays = DisplayCatalog.current() else {
            alert("디스플레이 조회 실패", "디스플레이 정보를 조회할 수 없습니다")
            return
        }

        do {
            let path = try WorkspaceRegistry().resolve(name)
            let config = try ConfigLoader.load(path: path)
            let resolved = WorkspaceResolver.resolve(config, displays: displays)
            let outcomes = await WorkspaceRunner().run(resolved)
            if let summary = MenuContent.failureSummary(outcomes) {
                alert("'\(name)' 일부 항목이 실패했습니다", summary)
            }
        } catch {
            alert("'\(name)' 실행 실패", "\(error)")
        }
    }

    @objc private func toggleLoginItem() {
        if let reason = LoginItem.toggle() {
            alert("로그인 항목 등록에 실패했습니다", reason)
        }
    }

    @objc private func openAccessibilitySettings() {
        _ = AccessibilityPermission.requestIfNeeded()
        guard let url = URL(string: AccessibilityPermission.settingsDeepLink) else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func revealConfigFolder() {
        let directory = WorkspaceRegistry.defaultDirectory
        if !FileManager.default.fileExists(atPath: directory) {
            try? FileManager.default.createDirectory(
                atPath: directory, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: directory))
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    /// 성공했을 때는 아무것도 띄우지 않는다. 워크스페이스가 눈앞에 배치되는 것이 피드백이다.
    private func alert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
