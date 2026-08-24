import AppKit
import RestageBrand
import RestageKitDarwin
import SwiftUI

/// 메뉴바 상태 항목과 패널의 수명을 관리한다.
///
/// `NSMenu` 대신 창을 띄우는 이유는 메뉴의 생김새를 바꿀 수 없기 때문이다. 배경, 글꼴,
/// 간격이 전부 시스템 고정이라 카드나 진행 표시를 넣을 수 없다.
///
/// `NSPopover`도 쓰지 않는다. 그것은 상태 항목 버튼에 묶여서, 메뉴바가 숨거나 나타나면
/// 딸려 닫힌다. 전체화면 앱 위에서 커서를 화면 위쪽에 올리기만 해도 사라진다.
@MainActor
final class PopoverController: NSObject, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength)
    private let store = PanelStore()
    private let menu = PanelMenu()

    private var window: PanelWindow?
    /// 패널이 떠 있는 동안 바깥 클릭을 지켜보는 감시자.
    private var outsideClickMonitor: Any?

    private static let panelWidth: CGFloat = 320
    /// 메뉴바와 패널 사이 간격.
    private static let topGap: CGFloat = 1
    /// 버튼과 메뉴 사이 간격.
    private static let menuGap: CGFloat = 3
    private static let screenInset: CGFloat = 8

    /// 그림자 여백을 뺀, 실제로 보이는 패널의 폭.
    private static var visibleWidth: CGFloat { panelWidth }

    func start() {
        statusItem.button?.image = MenuBarIcon.image()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)

        if !AccessibilityPermission.isTrusted() {
            _ = AccessibilityPermission.requestIfNeeded()
        }
        store.installHotkeys()
    }

    // MARK: - 열고 닫기

    @objc private func togglePanel() {
        if window?.isVisible == true {
            closePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        guard let buttonFrame = buttonScreenFrame() else { return }
        store.reload()

        let visibleLeft = visibleLeftEdge(under: buttonFrame)
        // 화살표가 아이콘 가운데를 가리키게 한다. 패널이 화면 가장자리에 밀리면 아이콘과
        // 어긋나므로 밀린 만큼을 화살표 위치에 되돌려준다.
        let arrowOffset = buttonFrame.midX - visibleLeft

        let panel = WorkspacePanel(
            store: store,
            dismiss: { [weak self] in self?.closePanel() },
            reopen: { [weak self] in self?.showPanel() },
            presentMenu: { [weak self] items, anchor in self?.present(items, at: anchor) },
            onQuit: { NSApplication.shared.terminate(nil) })

        // 크기는 컨트롤러에 맡긴다. 뷰를 직접 넣고 프레임을 손으로 맞추면 뷰와 창의 크기가
        // 어긋나 아무것도 그려지지 않는다.
        let controller = NSHostingController(
            rootView: PanelChrome(arrowOffset: arrowOffset) { panel })
        let panelWindow = PanelWindow(controller: controller)
        panelWindow.delegate = self
        window?.orderOut(nil)
        window = panelWindow

        panelWindow.setContentSize(controller.view.fittingSize)
        panelWindow.setFrameTopLeftPoint(
            CGPoint(
                x: visibleLeft - PanelChromeMetrics.shadowMargin,
                y: buttonFrame.minY - Self.topGap + PanelChromeMetrics.shadowMargin))
        panelWindow.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        startWatchingOutsideClicks()
    }

    func closePanel() {
        stopWatchingOutsideClicks()
        window?.orderOut(nil)
    }

    /// 창에서 그림자 여백을 뺀, 눈에 보이는 사각형.
    private func visibleFrame(of window: NSWindow) -> CGRect {
        window.frame.insetBy(
            dx: PanelChromeMetrics.shadowMargin, dy: PanelChromeMetrics.shadowMargin)
    }

    /// 상태 항목 버튼의 화면 좌표. 메뉴바가 숨어 있으면 nil이다.
    private func buttonScreenFrame() -> CGRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    /// 보이는 패널의 왼쪽 끝. 아이콘 가운데에 맞추되 화면 밖으로 나가지 않게 당긴다.
    private func visibleLeftEdge(under button: CGRect) -> CGFloat {
        let center = CGPoint(x: button.midX, y: button.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? .zero
        return min(
            max(button.midX - Self.visibleWidth / 2, bounds.minX + Self.screenInset),
            bounds.maxX - Self.visibleWidth - Self.screenInset)
    }

    // MARK: - 메뉴

    /// 버튼의 창 좌표를 화면 좌표로 옮겨 메뉴를 띄운다.
    ///
    /// SwiftUI는 위에서 아래로 재고 AppKit 화면 좌표는 아래에서 위로 잰다. 그래서 창의
    /// 위쪽 경계에서 빼야 한다.
    private func present(_ items: [PanelMenu.Item], at anchor: CGRect) {
        guard let window else { return }
        // 앵커는 창 좌표다. 보이는 사각형을 기준으로 재면 그림자 여백만큼 더 내려간다.
        // 클릭 판정만 보이는 사각형을 쓰고, 위치는 창을 그대로 쓴다.
        let point = CGPoint(
            x: window.frame.minX + anchor.minX,
            y: window.frame.maxY - anchor.maxY - Self.menuGap)

        menu.show(items: items, at: point) { [weak self] in
            self?.closePanelIfClickedOutside()
        }
    }

    // MARK: - 바깥 클릭

    /// 어디를 눌렀는지 보고 패널을 닫을지 정한다.
    ///
    /// 패널 안을 눌렀으면 그대로 둔다. 메뉴를 잘못 열었을 때 패널까지 사라지면 다시
    /// 열어야 한다. 패널 바깥을 눌렀으면 볼 일이 끝난 것이므로 닫는다.
    ///
    /// 상태 항목 자기 자신은 뺀다. 그것까지 닫으면 토글이 닫고 다시 여는 꼴이 된다.
    private func closePanelIfClickedOutside() {
        guard let window, window.isVisible else { return }
        let point = NSEvent.mouseLocation

        // 창 사각형이 아니라 눈에 보이는 부분으로 판정한다. 창에는 그림자 여백이 붙어
        // 있어서 위쪽 여백이 메뉴바와 겹친다. 창으로 재면 메뉴바의 다른 아이콘을 눌러도
        // "패널 안을 눌렀다"가 되어 닫히지 않는다. 실제로 겪었다.
        if visibleFrame(of: window).contains(point) { return }
        if let button = buttonScreenFrame(), button.contains(point) { return }
        closePanel()
    }

    /// 다른 창이 키를 가져가면 물러난다.
    ///
    /// 바깥 클릭 감시자만으로는 부족하다. 다른 메뉴바 앱이 패널이나 메뉴를 띄우면 그쪽이
    /// 추적 루프를 돌려 우리 감시자에 클릭이 오지 않는다. 키를 잃는 것은 그때도 온다.
    ///
    /// 우리 메뉴가 떠 있는 동안은 빼야 한다. 메뉴가 키를 가져가므로, 그러지 않으면
    /// 메뉴를 여는 순간 패널이 닫힌다.
    func windowDidResignKey(_ notification: Notification) {
        guard !menu.isShowing else { return }
        closePanel()
    }

    /// 창은 스스로 닫히지 않으므로 바깥 클릭을 직접 지켜본다.
    /// 마우스 이벤트만 보므로 추가 권한이 필요하지 않다.
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
}
