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
    /// 패널이 떠 있는 동안 바깥 클릭을 지켜보는 감시자.
    private var outsideClickMonitor: Any?

    func start() {
        statusItem.button?.image = MenuBarIcon.image()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)

        // 닫는 판단을 전부 직접 한다. `.transient`는 메뉴바가 자동으로 숨었다 나타나는
        // 것까지 "바깥 상호작용"으로 보고 패널을 닫는다. 커서를 화면 위쪽에 올렸을 뿐인데
        // 사라지는 이유가 그것이다. 바깥 클릭은 이미 직접 지켜보고 있으므로 필요 없다.
        popover.behavior = .applicationDefined
        popover.delegate = self
        // 여는 것도 닫는 것도 즉시. 메뉴는 애니메이션 없이 사라지므로, 패널만 서서히
        // 사라지면 둘이 따로 노는 것처럼 보인다.
        popover.animates = false
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
            self?.closePanelIfClickedOutside()
        }
    }

    /// 어디를 눌렀는지 보고 패널을 닫을지 정한다.
    ///
    /// 패널 안을 눌렀으면 그대로 둔다. 메뉴를 잘못 열었을 때 패널까지 사라지면 다시
    /// 열어야 한다. 패널 바깥을 눌렀으면 볼 일이 끝난 것이므로 닫는다.
    ///
    /// 상태 항목 자기 자신은 뺀다. 그것까지 닫으면 토글이 닫고 다시 여는 꼴이 된다.
    private func closePanelIfClickedOutside() {
        guard popover.isShown else { return }
        let point = NSEvent.mouseLocation

        if let window = popover.contentViewController?.view.window,
           window.frame.contains(point) { return }
        if let button = statusItem.button, let window = button.window,
           window.convertToScreen(button.convert(button.bounds, to: nil)).contains(point) {
            return
        }
        popover.close()
    }

    /// 팝오버의 transient 동작은 다른 메뉴바 항목을 누르는 것을 잡지 못한다. 그 앱들도
    /// 대개 배경 앱이라 우리 앱이 활성에서 물러나지 않기 때문이다. 그래서 직접 지켜본다.
    ///
    /// 키보드가 아니라 마우스 이벤트만 보므로 추가 권한이 필요하지 않다.
    private func startWatchingOutsideClicks() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePanelIfClickedOutside() }
        }
    }

    private func stopWatchingOutsideClicks() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    func popoverDidClose(_ notification: Notification) {
        stopWatchingOutsideClicks()
    }

    /// 버튼과 메뉴 사이 간격.
    private static let menuGap: CGFloat = 9

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
        startWatchingOutsideClicks()
        // 팝오버는 앱이 활성 상태가 아니면 키 입력을 받지 못한다. 이 앱은 LSUIElement라
        // 스스로 활성화해야 텍스트 필드나 메뉴가 정상 동작한다.
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
