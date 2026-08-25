import AppKit
import CoreGraphics
import Foundation
import RestageKit

@MainActor
enum FullScreenController {
    static let transitionTimeout: Duration = .seconds(5)

    static let frameChangeTimeout: Duration = .seconds(2)

    static func enter(_ window: AXWindow) async -> PlacementResult {
        let before = window.currentFrame
        if window.isFullScreen {
            return .ok(actual: before ?? .zero, attempts: 0, elapsed: .zero, warnings: [])
        }

        guard window.hasFullScreenButton else {
            return .constrained(
                actual: before ?? .zero,
                expected: before ?? .zero,
                reason: L10n.string("error.fullscreen.unsupported"))
        }

        let clock = ContinuousClock()
        let start = clock.now

        await raiseAndWait(pid: window.pid)
        window.setMain(true)

        if window.setFullScreen(true), await confirmed(window, changedFrom: before) {
            return success(window, start: start, attempts: 1)
        }

        if window.isFullScreen { window.setFullScreen(false) }
        _ = await Polling.poll(timeout: frameChangeTimeout) {
            window.isFullScreen ? nil : true
        }

        if window.pressFullScreenButton(), await confirmed(window, changedFrom: before) {
            return success(window, start: start, attempts: 2)
        }

        return .failed(
            expected: before ?? .zero,
            actual: window.currentFrame,
            reason: L10n.string("error.fullscreen.not_completed"))
    }

    @discardableResult
    static func exit(_ window: AXWindow) async -> Bool {
        guard window.isFullScreen else { return true }
        let before = window.currentFrame

        await raiseAndWait(pid: window.pid)
        window.setMain(true)
        window.setFullScreen(false)

        let cleared = await Polling.poll(timeout: transitionTimeout) {
            window.isFullScreen ? nil : true
        }
        guard cleared == true else { return false }

        if let before {
            _ = await Polling.poll(timeout: transitionTimeout) {
                window.currentFrame.map { $0 != before } == true ? true : nil
            }
        }
        _ = await Polling.settle(timeout: transitionTimeout) { window.currentFrame }
        return !window.isFullScreen
    }

    private static func raiseAndWait(pid: Int32) async {
        AXWindow.setApplicationFrontmost(pid: pid)
        _ = await Polling.poll(timeout: frameChangeTimeout) {
            NSWorkspace.shared.frontmostApplication?.processIdentifier == pid ? true : nil
        }
    }

    private static func confirmed(_ window: AXWindow, changedFrom before: CGRect?) async -> Bool {
        let flagged = await Polling.poll(timeout: transitionTimeout) {
            window.isFullScreen ? true : nil
        }
        guard flagged == true else { return false }

        if let before {
            let changed = await Polling.poll(timeout: frameChangeTimeout) {
                window.currentFrame.map { $0 != before } == true ? true : nil
            }
            guard changed == true else { return false }
        }
        _ = await Polling.settle(timeout: transitionTimeout) { window.currentFrame }

        if let before, window.currentFrame == before { return false }
        return true
    }

    private static func success(
        _ window: AXWindow, start: ContinuousClock.Instant, attempts: Int
    ) -> PlacementResult {
        .ok(
            actual: window.currentFrame ?? .zero,
            attempts: attempts,
            elapsed: start.duration(to: ContinuousClock().now),
            warnings: [])
    }
}
