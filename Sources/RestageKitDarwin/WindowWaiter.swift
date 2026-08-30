import RestageKit

@MainActor
public enum WindowWaiter {
    static let activationGrace: Duration = .milliseconds(750)

    static let layoutSettleTimeout: Duration = .seconds(2)

    static let splashGrace: Duration = .seconds(4)

    static let spaceReturnTimeout: Duration = .seconds(3)

    public static func wait(
        pid: Int32, timeout: Duration, selector: WindowSelector = .mostRecentlyActive,
        mayFollowOtherSpaces: Bool = false, claims: WindowClaims? = nil
    ) async throws -> AXWindow {
        var lastError: Error?
        var fixedSizeCandidate: AXWindow?
        var fixedSizeSeenAt: ContinuousClock.Instant?
        var seenTitles: [String] = []
        var exhaustedSeenAt: ContinuousClock.Instant?
        var newWindowDeadline: ContinuousClock.Instant?
        var triedNewWindow = false
        var openedNewWindow = false
        var taken = 0
        var activated = false
        let clock = ContinuousClock()
        let activationDeadline = clock.now.advanced(by: activationGrace)

        let found = try await Polling.poll(timeout: timeout) { () -> AXWindow? in
            do {
                let all = try AXWindow.windows(ofPID: pid)
                let titles = all.filter(isRealWindow).compactMap { $0.title }
                if !titles.isEmpty { seenTitles = titles }
                let matched = matching(all, selector)
                let windows = matched.filter { !(claims?.contains($0) ?? false) }
                if var window = windows.first(where: isPlaceable) {
                    claims?.claim(window)
                    window.wasOpened = openedNewWindow
                    return window
                }

                if let candidate = windows.first(where: isRealWindow) {
                    if fixedSizeCandidate == nil {
                        fixedSizeCandidate = candidate
                        fixedSizeSeenAt = clock.now
                    }
                    if let seenAt = fixedSizeSeenAt,
                       clock.now >= seenAt.advanced(by: splashGrace) {
                        claims?.claim(candidate)
                        return candidate
                    }
                }

                taken = windows.isEmpty ? matched.filter(isRealWindow).count : 0
            } catch {
                lastError = error
                return nil
            }

            if claims != nil, taken > 0, clock.now >= activationDeadline,
               WindowInventory.hereCount(pid: pid) > 0 {
                let seenAt = exhaustedSeenAt ?? clock.now
                exhaustedSeenAt = seenAt
                if clock.now >= seenAt.advanced(by: layoutSettleTimeout) {
                    if !triedNewWindow {
                        triedNewWindow = true
                        if NewWindowOpener.open(pid: pid) {
                            openedNewWindow = true
                            newWindowDeadline = clock.now.advanced(
                                by: NewWindowOpener.appearTimeout)
                        }
                    }
                    if let newWindowDeadline, clock.now < newWindowDeadline { return nil }
                    throw EngineError.windowsExhausted(pid: pid, have: taken)
                }
            } else {
                exhaustedSeenAt = nil
            }

            if !activated, clock.now >= activationDeadline {
                activated = true
                try reach(pid: pid, mayFollowOtherSpaces: mayFollowOtherSpaces)
            }
            return nil
        }

        if let found { return found }
        if let fixedSizeCandidate {
            claims?.claim(fixedSizeCandidate)
            return fixedSizeCandidate
        }
        if let lastError { throw lastError }

        if let wanted = selector.titleContains {
            throw EngineError.noWindowMatchingTitle(
                pid: pid, wanted: wanted, available: seenTitles)
        }

        if let census = WindowInventory.census(pid: pid) {
            if census.here.isEmpty, !census.elsewhere.isEmpty {
                throw EngineError.windowOnOtherSpace(
                    pid: pid, windowCount: census.elsewhere.count)
            }
            if census.here.isEmpty, census.elsewhere.isEmpty, !census.offDisplay.isEmpty {
                throw EngineError.windowOffDisplay(
                    pid: pid, windowCount: census.offDisplay.count)
            }
            throw EngineError.windowTimeout(pid: pid, seconds: seconds(of: timeout))
        }

        let existing = WindowInventory.windowCount(pid: pid)
        let offDisplay = WindowInventory.offDisplayWindowCount(pid: pid)
        if existing > 0, offDisplay == existing {
            throw EngineError.windowOffDisplay(pid: pid, windowCount: offDisplay)
        }
        let elsewhere = existing - WindowInventory.onScreenWindowCount(pid: pid)
        if elsewhere > 0 {
            throw EngineError.windowOnOtherSpace(pid: pid, windowCount: elsewhere)
        }
        throw EngineError.windowTimeout(pid: pid, seconds: seconds(of: timeout))
    }

    private static func reach(pid: Int32, mayFollowOtherSpaces: Bool) throws {
        guard let census = WindowInventory.census(pid: pid) else {
            let onScreen = WindowInventory.onScreenWindowCount(pid: pid)
            let anywhere = WindowInventory.windowCount(pid: pid)
            if shouldActivate(onScreen: onScreen, anywhere: anywhere) || mayFollowOtherSpaces {
                WindowInventory.unhide(pid: pid)
                AXWindow.setApplicationFrontmost(pid: pid)
                return
            }
            if WindowInventory.offDisplayWindowCount(pid: pid) == anywhere {
                throw EngineError.windowOffDisplay(pid: pid, windowCount: anywhere)
            }
            throw EngineError.windowOnOtherSpace(pid: pid, windowCount: anywhere - onScreen)
        }

        if shouldActivate(onScreen: census.here.count, anywhere: census.real) {
            WindowInventory.unhide(pid: pid)
            AXWindow.setApplicationFrontmost(pid: pid)
            return
        }
        guard !census.elsewhere.isEmpty else {
            throw EngineError.windowOffDisplay(pid: pid, windowCount: census.offDisplay.count)
        }
        guard mayFollowOtherSpaces, follow(pid: pid) else {
            throw EngineError.windowOnOtherSpace(pid: pid, windowCount: census.elsewhere.count)
        }
        WindowInventory.unhide(pid: pid)
        AXWindow.setApplicationFrontmost(pid: pid)
    }

    private static func followBack(_ window: AXWindow) async {
        guard window.isStale, follow(pid: window.pid) else { return }
        _ = await Polling.poll(timeout: spaceReturnTimeout) {
            window.isStale ? nil : true
        }
    }

    @discardableResult
    static func follow(pid: Int32) -> Bool {
        guard let space = WindowInventory.spaceOfWindowElsewhere(pid: pid),
              let display = SpaceInventory.display(of: space) else { return false }
        return SpaceInventory.show(space: space, on: display)
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
            await followBack(window)
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
