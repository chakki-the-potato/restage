import RestageKit

@MainActor
public enum WindowWaiter {
    static let activationGrace: Duration = .milliseconds(750)

    static let layoutSettleTimeout: Duration = .seconds(2)

    static let splashGrace: Duration = .seconds(4)

    public static func wait(
        pid: Int32, timeout: Duration, selector: WindowSelector = .mostRecentlyActive,
        mayFollowOtherSpaces: Bool = false
    ) async throws -> AXWindow {
        var lastError: Error?
        var fixedSizeCandidate: AXWindow?
        var fixedSizeSeenAt: ContinuousClock.Instant?
        var seenTitles: [String] = []
        var activated = false
        let clock = ContinuousClock()
        let activationDeadline = clock.now.advanced(by: activationGrace)

        let found = try await Polling.poll(timeout: timeout) { () -> AXWindow? in
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
                let onScreen = WindowInventory.onScreenWindowCount(pid: pid)
                let anywhere = WindowInventory.windowCount(pid: pid)
                if shouldActivate(onScreen: onScreen, anywhere: anywhere)
                    || mayFollowOtherSpaces {
                    AXWindow.setApplicationFrontmost(pid: pid)
                } else if WindowInventory.offDisplayWindowCount(pid: pid) == anywhere {
                    throw EngineError.windowOffDisplay(pid: pid, windowCount: anywhere)
                } else {
                    throw EngineError.windowOnOtherSpace(pid: pid, windowCount: anywhere)
                }
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
        let offDisplay = WindowInventory.offDisplayWindowCount(pid: pid)
        if existing > 0, offDisplay == existing {
            throw EngineError.windowOffDisplay(pid: pid, windowCount: offDisplay)
        }
        if existing > 0 {
            throw EngineError.windowOnOtherSpace(pid: pid, windowCount: existing)
        }
        throw EngineError.windowTimeout(pid: pid, seconds: seconds(of: timeout))
    }

    public static func shouldActivate(onScreen: Int, anywhere: Int) -> Bool {
        if onScreen > 0 { return true }
        return anywhere == 0
    }

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

    private static func matching(_ windows: [AXWindow], _ selector: WindowSelector) -> [AXWindow] {
        guard let wanted = selector.titleContains?.lowercased() else { return windows }
        return windows.filter { $0.title?.lowercased().contains(wanted) == true }
    }

    private static func isPlaceable(_ window: AXWindow) -> Bool {
        isRealWindow(window) && window.isSizeSettable
    }

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
