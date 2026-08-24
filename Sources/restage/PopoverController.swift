import AppKit
import RestageBrand
import RestageKitDarwin
import SwiftUI

/// 메뉴바 상태 항목과 패널의 수명을 관리한다.
///
/// `NSMenu` 대신 `NSPopover`를 쓰는 이유는 메뉴의 생김새를 바꿀 수 없기 때문이다.
/// 배경, 글꼴, 간격이 전부 시스템 고정이라 카드나 진행 표시를 넣을 수 없다.
@MainActor
final class PopoverController: NSObject, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let store = PanelStore()

    func start() {
        statusItem.button?.image = MenuBarIcon.image()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)

        popover.behavior = .transient
        popover.delegate = self
        popover.contentViewController = hostingController()

        if !AccessibilityPermission.isTrusted() {
            _ = AccessibilityPermission.requestIfNeeded()
        }
        store.installHotkeys()
    }

    private func hostingController() -> NSHostingController<WorkspacePanel> {
        let panel = WorkspacePanel(
            store: store,
            dismiss: { [weak self] in self?.popover.performClose(nil) },
            reopen: { [weak self] in self?.showPanel() },
            onQuit: { NSApplication.shared.terminate(nil) })
        let controller = NSHostingController(rootView: panel)
        // 내용 높이에 맞춰 패널이 늘어나게 한다. 고정하면 워크스페이스가 늘 때 잘린다.
        controller.sizingOptions = [.preferredContentSize]
        return controller
    }

    @objc private func togglePanel() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        showPanel()
    }

    func showPanel() {
        guard let button = statusItem.button, !popover.isShown else { return }
        store.reload()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // 팝오버는 앱이 활성 상태가 아니면 키 입력을 받지 못한다. 이 앱은 LSUIElement라
        // 스스로 활성화해야 텍스트 필드나 메뉴가 정상 동작한다.
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
