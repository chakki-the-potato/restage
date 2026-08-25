import AppKit
import RestageBrand
import RestageKitDarwin
import SwiftUI

@MainActor
final class PopoverController: NSObject, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength)
    private let store = PanelStore()
    private let menu = PanelMenu()

    private var window: PanelWindow?
    private var outsideClickMonitor: Any?

    private static let panelWidth: CGFloat = 320
    private static let topGap: CGFloat = 1
    private static let menuGap: CGFloat = 5
    private static let screenInset: CGFloat = 8

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
        let arrowOffset = buttonFrame.midX - visibleLeft

        let panel = WorkspacePanel(
            store: store,
            dismiss: { [weak self] in self?.closePanel() },
            reopen: { [weak self] in self?.showPanel() },
            presentMenu: { [weak self] items, anchor in self?.present(items, at: anchor) },
            onQuit: { NSApplication.shared.terminate(nil) })

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

    private func visibleFrame(of window: NSWindow) -> CGRect {
        window.frame.insetBy(
            dx: PanelChromeMetrics.shadowMargin, dy: PanelChromeMetrics.shadowMargin)
    }

    private func buttonScreenFrame() -> CGRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func visibleLeftEdge(under button: CGRect) -> CGFloat {
        let center = CGPoint(x: button.midX, y: button.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? .zero
        return min(
            max(button.midX - Self.visibleWidth / 2, bounds.minX + Self.screenInset),
            bounds.maxX - Self.visibleWidth - Self.screenInset)
    }

    private func present(_ items: [PanelMenu.Item], at anchor: CGRect) {
        guard let window else { return }
        let point = CGPoint(
            x: window.frame.minX + anchor.minX,
            y: window.frame.maxY - anchor.maxY - Self.menuGap)

        menu.show(items: items, at: point) { [weak self] in
            self?.closePanelIfClickedOutside()
        }
    }

    private func closePanelIfClickedOutside() {
        guard let window, window.isVisible else { return }
        let point = NSEvent.mouseLocation

        if visibleFrame(of: window).contains(point) { return }
        if let button = buttonScreenFrame(), button.contains(point) { return }
        closePanel()
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !menu.isShowing else { return }
        guard !MenuBarZone.contains(NSEvent.mouseLocation) else { return }
        closePanel()
    }

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
