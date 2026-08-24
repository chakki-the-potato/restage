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
    private let menu = PanelMenu()

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

        // 메뉴바의 다른 항목을 누르면 우리 앱이 활성에서 물러난다. 그때 패널을 닫는다.
        // 팝오버의 transient 동작만으로는 다른 상태 항목의 창이 뜨는 것을 잡지 못한다.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.popover.performClose(nil) }
        }
    }

    private func hostingController() -> NSHostingController<WorkspacePanel> {
        let panel = WorkspacePanel(
            store: store,
            dismiss: { [weak self] in self?.popover.performClose(nil) },
            reopen: { [weak self] in self?.showPanel() },
            presentMenu: { [weak self] items, anchor in
                self?.present(items, at: anchor)
            },
            onQuit: { NSApplication.shared.terminate(nil) })
        let controller = NSHostingController(rootView: panel)
        // 내용 높이에 맞춰 패널이 늘어나게 한다. 고정하면 워크스페이스가 늘 때 잘린다.
        controller.sizingOptions = [.preferredContentSize]
        return controller
    }

    /// 버튼의 창 좌표를 화면 좌표로 옮겨 메뉴를 띄운다.
    ///
    /// SwiftUI는 위에서 아래로 재고 AppKit 화면 좌표는 아래에서 위로 잰다. 그래서 창의
    /// 위쪽 경계에서 빼야 한다.
    private func present(_ items: [PanelMenu.Item], at anchor: CGRect) {
        guard let window = popover.contentViewController?.view.window else { return }
        let point = CGPoint(
            x: window.frame.minX + anchor.minX,
            y: window.frame.maxY - anchor.maxY - Self.menuGap)

        menu.show(items: items, at: point) { [weak self] in
            // 항목을 고르지 않고 닫혔다. 바깥을 눌렀다는 뜻이므로 패널도 닫는다.
            self?.popover.performClose(nil)
        }
    }

    private static let menuGap: CGFloat = 4

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
