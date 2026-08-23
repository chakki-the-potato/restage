import AppKit
import RestageKit
import RestageKitDarwin

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength)
    private var isRunning = false

    func start() {
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.3.group", accessibilityDescription: "restage")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        if !AccessibilityPermission.isTrusted() {
            _ = AccessibilityPermission.requestIfNeeded()
        }

    }

    /// 메뉴를 열 때마다 다시 만든다.
    ///
    /// 한 번만 만들면 config 파일을 고친 뒤 앱을 재시작해야 한다. 파일을 직접 편집하는
    /// 것이 이 도구의 편집 방식이므로 재시작이 필요하면 쓰기 어렵다.
    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        let result = Result { try WorkspaceRegistry().list() }
        for entry in MenuContent.entries(for: result) {
            let item = NSMenuItem(
                title: entry.title, action: #selector(openWorkspace(_:)), keyEquivalent: "")
            item.isEnabled = entry.isEnabled && !isRunning
            item.toolTip = entry.tooltip
            item.target = entry.isEnabled ? self : nil
            if case .workspace(let name) = entry { item.representedObject = name }
            menu.addItem(item)
        }

        menu.addItem(.separator())
        addAction(to: menu, title: "config 폴더 열기", selector: #selector(revealConfigFolder))
        addAction(to: menu, title: "종료", selector: #selector(quit), keyEquivalent: "q")
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
