import RestageKit

@MainActor
public enum WindowWaiter {
    /// How long to wait before falling back to activating the app.
    static let activationGrace: Duration = .milliseconds(750)

    /// How long to wait for an app to finish its own layout before placing anything.
    /// Placing while it is still sizing itself right after launch makes the two overwrite each other.
    static let layoutSettleTimeout: Duration = .seconds(2)

    /// How long to wait before accepting a fixed-size window as the final candidate.
    /// It buys time for a splash to be replaced by the real window. Measured, Discord swaps within 3s.
    static let splashGrace: Duration = .seconds(4)

    /// Polls until a placeable window appears.
    /// Conditions: AXRole == AXWindow, size greater than zero, not minimized.
    /// Returns the first of the AX window list, that is the most recently active window.
    ///
    /// Some apps don't build their AX window tree until they come to the front. Safari does this.
    /// `AXWindows` returns an empty array even though the window is open and visible.
    /// So when no window is found within `activationGrace`, the app is activated once and polling continues.
    /// Activating from the start is avoided because apps stealing focus from each other mid-placement
    /// would fight the final step that focuses the anchor app.
    public static func wait(
        pid: Int32, timeout: Duration, selector: WindowSelector = .mostRecentlyActive
    ) async throws -> AXWindow {
        var lastError: Error?
        var fixedSizeCandidate: AXWindow?
        var fixedSizeSeenAt: ContinuousClock.Instant?
        var seenTitles: [String] = []
        var activated = false
        let clock = ContinuousClock()
        let activationDeadline = clock.now.advanced(by: activationGrace)

        let found = await Polling.poll(timeout: timeout) { () -> AXWindow? in
            do {
                let all = try AXWindow.windows(ofPID: pid)
                let titles = all.filter(isRealWindow).compactMap { $0.title }
                if !titles.isEmpty { seenTitles = titles }
                let windows = matching(all, selector)
                if let window = windows.first(where: isPlaceable) { return window }

                if let candidate = windows.first(where: isRealWindow) {
                    if fixedSizeCandidate == nil {
                        fixedSizeCandidate = candidate
                        fixedSizeSeenAt = clock.now
                    }
                    if let seenAt = fixedSizeSeenAt,
                       clock.now >= seenAt.advanced(by: splashGrace) {
                        return candidate
                    }
                }
            } catch {
                lastError = error
                return nil
            }

            if !activated, clock.now >= activationDeadline {
                activated = true
                AXWindow.setApplicationFrontmost(pid: pid)
            }
            return nil
        }

        if let found { return found }
        if let fixedSizeCandidate { return fixedSizeCandidate }
        if let lastError { throw lastError }

        if let wanted = selector.titleContains {
            throw EngineError.noWindowMatchingTitle(
                pid: pid, wanted: wanted, available: seenTitles)
        }

        let existing = WindowInventory.windowCount(pid: pid)
        if existing > 0 {
            throw EngineError.windowOnOtherSpace(pid: pid, windowCount: existing)
        }
        throw EngineError.windowTimeout(pid: pid, seconds: seconds(of: timeout))
    }

    /// Settles a window before placing it: unminimize, and leave full screen if needed.
    /// Returns once the size has stopped changing.
    public static func prepareForDesktopPlacement(_ window: AXWindow) async {
        if window.isMinimized {
            window.setMinimized(false)
            _ = await Polling.settle(timeout: .seconds(2)) { window.currentFrame }
        }
        if window.isFullScreen {
            window.setFullScreen(false)
            _ = await Polling.settle(timeout: .seconds(3)) { window.currentFrame }
        }
        _ = await Polling.settle(timeout: layoutSettleTimeout) { window.currentFrame }
    }

    /// Titles seen while polling are remembered because looking again after a timeout returns an
    /// empty array — the app is no longer frontmost by then. That would report "no windows are
    /// open", which is not true.
    ///
    /// With a title given, only windows containing it are kept. Case is ignored.
    ///
    /// Among several matches the most recently active comes first, because the AX window list is in that order.
    private static func matching(_ windows: [AXWindow], _ selector: WindowSelector) -> [AXWindow] {
        guard let wanted = selector.titleContains?.lowercased() else { return windows }
        return windows.filter { $0.title?.lowercased().contains(wanted) == true }
    }

    /// A window that can also be resized. Preferred as the placement target.
    ///
    /// Resizability is part of the condition because of Electron splash windows. Right after launch
    /// Discord shows a fixed 300x300 window and swaps it for the real 1280x870 one a moment later.
    /// Without this condition the splash gets caught: it moves but fails to resize.
    private static func isPlaceable(_ window: AXWindow) -> Bool {
        isRealWindow(window) && window.isSizeSettable
    }

    /// A real window regardless of whether it can be resized. Used as the fallback on timeout.
    ///
    /// Some apps have nothing but fixed-size windows, like IINA's start window. Returning nothing
    /// there would report "no windows" incorrectly, so this window is handed over and the placement
    /// step reports CONSTRAINED with the size limit as the reason.
    private static func isRealWindow(_ window: AXWindow) -> Bool {
        guard window.role == AXAttributes.windowRole else { return false }
        guard !window.isMinimized else { return false }
        guard let frame = window.currentFrame else { return false }
        return frame.width > 0 && frame.height > 0
    }

    private static func seconds(of duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
