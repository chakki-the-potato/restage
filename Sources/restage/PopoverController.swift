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
final class PopoverController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength)
    private let store = PanelStore()
    private let menu = PanelMenu()

    private var window: PanelWindow?
    /// 패널이 떠 있는 동안 바깥 클릭을 지켜보는 감시자.
    private var outsideClickMonitor: Any?

    private static let panelWidth: CGFloat = 320
    /// 메뉴바와 패널 사이 간격.
    private static let topGap: CGFloat = 2
    /// 버튼과 메뉴 사이 간격.
    private static let menuGap: CGFloat = 9
    private static let screenInset: CGFloat = 8

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

        let origin = panelOrigin(under: buttonFrame)
        // 화살표가 아이콘 가운데를 가리키게 한다. 패널이 화면 가장자리에 붙어 밀리면
        // 아이콘과 어긋나므로 밀린 만큼을 화살표 위치에 되돌려준다.
        let arrowOffset = buttonFrame.midX - origin.x - PanelChromeMetrics.shadowMargin

        let panel = WorkspacePanel(
            store: store,
            dismiss: { [weak self] in self?.closePanel() },
            reopen: { [weak self] in self?.showPanel() },
            presentMenu: { [weak self] items, anchor in self?.present(items, at: anchor) },
            onQuit: { NSApplication.shared.terminate(nil) })

        let view = NSHostingView(rootView: PanelChrome(arrowOffset: arrowOffset) { panel })
        let panelWindow = window ?? PanelWindow(content: view)
        panelWindow.contentView = view
        window = panelWindow

        // 높이를 재려면 폭을 정하고 배치를 한 번 돌려야 한다. 이때 높이를 1로 두면
        // 그 안에 욱여넣은 결과가 나와 내용이 잘린다. 넉넉히 주고 잰다.
        let width = Self.panelWidth + PanelChromeMetrics.shadowMargin * 2
        view.frame = NSRect(x: 0, y: 0, width: width, height: 2000)
        view.layoutSubtreeIfNeeded()
        let size = NSSize(width: width, height: max(view.fittingSize.height, 1))

        panelWindow.setFrame(
            NSRect(x: origin.x, y: origin.y - size.height, width: size.width, height: size.height),
            display: true)
        panelWindow.orderFrontRegardless()
        panelWindow.makeKey()
        NSApplication.shared.activate(ignoringOtherApps: true)
        startWatchingOutsideClicks()
    }

    func closePanel() {
        stopWatchingOutsideClicks()
        window?.orderOut(nil)
    }

    /// 상태 항목 버튼의 화면 좌표. 메뉴바가 숨어 있으면 nil이다.
    private func buttonScreenFrame() -> CGRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    /// 패널의 왼쪽 위 모서리. 아이콘 가운데에 맞추되 화면 밖으로 나가지 않게 당긴다.
    private func panelOrigin(under button: CGRect) -> CGPoint {
        let center = CGPoint(x: button.midX, y: button.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? .zero
        let x = min(
            max(button.midX - Self.panelWidth / 2, bounds.minX + Self.screenInset),
            bounds.maxX - Self.panelWidth - Self.screenInset)
        // 창은 그림자 여백만큼 넓고 높다. 보이는 부분이 제자리에 오도록 그만큼 되민다.
        return CGPoint(
            x: x - PanelChromeMetrics.shadowMargin,
            y: button.minY - Self.topGap + PanelChromeMetrics.shadowMargin)
    }

    // MARK: - 메뉴

    /// 버튼의 창 좌표를 화면 좌표로 옮겨 메뉴를 띄운다.
    ///
    /// SwiftUI는 위에서 아래로 재고 AppKit 화면 좌표는 아래에서 위로 잰다. 그래서 창의
    /// 위쪽 경계에서 빼야 한다.
    private func present(_ items: [PanelMenu.Item], at anchor: CGRect) {
        guard let window else { return }
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

        if window.frame.contains(point) { return }
        if let button = buttonScreenFrame(), button.contains(point) { return }
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
