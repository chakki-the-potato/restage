import AppKit
import RestageBrand
import RestageKitDarwin
import SwiftUI

/// Owns the menu bar status item and the lifetime of the panel.
///
/// A window is used instead of `NSMenu` because a menu's looks can't be changed. Background,
/// font, and spacing are all fixed by the system, leaving no room for cards or progress.
///
/// `NSPopover` is out too. It is tied to the status item button, so it closes along with the
/// menu bar hiding or appearing — moving the cursor to the top over a full screen app is enough.
@MainActor
final class PopoverController: NSObject, NSWindowDelegate {
    private let statusItem = NSStatusBar.system.statusItem(
        withLength: NSStatusItem.variableLength)
    private let store = PanelStore()
    private let menu = PanelMenu()

    private var window: PanelWindow?
    /// Watches for clicks outside while the panel is up.
    private var outsideClickMonitor: Any?

    private static let panelWidth: CGFloat = 320
    /// The gap between the menu bar and the panel.
    private static let topGap: CGFloat = 1
    /// The gap between the button and the menu.
    private static let menuGap: CGFloat = 5
    private static let screenInset: CGFloat = 8

    /// The width the panel actually shows, shadow margin excluded.
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

    // MARK: - Opening and closing

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
        // Point the arrow at the middle of the icon. When the panel is pushed in from a screen
        // edge it no longer lines up, so give the arrow back however far it was pushed.
        let arrowOffset = buttonFrame.midX - visibleLeft

        let panel = WorkspacePanel(
            store: store,
            dismiss: { [weak self] in self?.closePanel() },
            reopen: { [weak self] in self?.showPanel() },
            presentMenu: { [weak self] items, anchor in self?.present(items, at: anchor) },
            onQuit: { NSApplication.shared.terminate(nil) })

        // The controller owns the size. Putting the view in directly and setting the frame by
        // hand leaves view and window out of step, and nothing gets drawn at all.
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

    /// The visible rectangle of a window, shadow margin excluded.
    private func visibleFrame(of window: NSWindow) -> CGRect {
        window.frame.insetBy(
            dx: PanelChromeMetrics.shadowMargin, dy: PanelChromeMetrics.shadowMargin)
    }

    /// Screen coordinates of the status item button. nil while the menu bar is hidden.
    private func buttonScreenFrame() -> CGRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    /// The left edge of the visible panel: centered under the icon, pulled in to stay on screen.
    private func visibleLeftEdge(under button: CGRect) -> CGFloat {
        let center = CGPoint(x: button.midX, y: button.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        let bounds = screen?.visibleFrame ?? .zero
        return min(
            max(button.midX - Self.visibleWidth / 2, bounds.minX + Self.screenInset),
            bounds.maxX - Self.visibleWidth - Self.screenInset)
    }

    // MARK: - The menu

    /// Moves the button's window coordinates to screen coordinates and opens the menu there.
    ///
    /// SwiftUI measures top-down and AppKit screen coordinates measure bottom-up, so it has to be
    /// subtracted from the window's top edge.
    private func present(_ items: [PanelMenu.Item], at anchor: CGRect) {
        guard let window else { return }
        // The anchor is in window coordinates. Measuring from the visible rectangle would drop it
        // by the shadow margin. Only the hit test uses the visible rectangle; position uses the window.
        let point = CGPoint(
            x: window.frame.minX + anchor.minX,
            y: window.frame.maxY - anchor.maxY - Self.menuGap)

        menu.show(items: items, at: point) { [weak self] in
            self?.closePanelIfClickedOutside()
        }
    }

    // MARK: - Clicks outside

    /// Decides whether a click should close the panel.
    ///
    /// A click inside leaves it alone: if opening a menu by mistake also took the panel away, it
    /// would have to be reopened. A click outside means the visit is over, so it closes.
    ///
    /// The status item itself is excluded. Closing on that would make the toggle close and reopen.
    private func closePanelIfClickedOutside() {
        guard let window, window.isVisible else { return }
        let point = NSEvent.mouseLocation

        // The test uses the visible part, not the window rectangle. The window carries a shadow
        // margin whose top overlaps the menu bar, so measuring by the window would count a click
        // on another menu bar icon as "inside the panel" and never close. That happened.
        if visibleFrame(of: window).contains(point) { return }
        if let button = buttonScreenFrame(), button.contains(point) { return }
        closePanel()
    }

    /// Steps back when another window takes key.
    ///
    /// The outside-click monitor isn't enough on its own. When another menu bar app puts up a
    /// panel or menu, its tracking loop keeps the click from us. Losing key still arrives.
    ///
    /// Our own menu has to be excluded. It takes key, so without this the panel would close the
    /// moment the menu opens.
    func windowDidResignKey(_ notification: Notification) {
        guard !menu.isShowing else { return }
        // Losing key happens from the menu bar merely appearing. Nothing was pressed, so don't close.
        // A real click on another menu bar icon is closed by the outside-click monitor.
        guard !MenuBarZone.contains(NSEvent.mouseLocation) else { return }
        closePanel()
    }

    /// A window doesn't close itself, so clicks outside are watched directly.
    /// Only mouse events are read, so no extra permission is needed.
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
