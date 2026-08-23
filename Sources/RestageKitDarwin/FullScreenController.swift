import CoreGraphics
import Foundation
import RestageKit

@MainActor
enum FullScreenController {
    static let transitionTimeout: Duration = .seconds(5)

    static func enter(_ window: AXWindow) async -> PlacementResult {
        let before = window.currentFrame
        if window.isFullScreen {
            return .ok(actual: before ?? .zero, attempts: 0, elapsed: .zero, warnings: [])
        }

        let clock = ContinuousClock()
        let start = clock.now

        if window.setFullScreen(true), await confirmed(window) {
            return success(window, start: start, attempts: 1)
        }

        guard window.hasFullScreenButton else {
            return .constrained(
                actual: window.currentFrame ?? .zero,
                expected: before ?? .zero,
                reason: "전체화면을 지원하지 않는 창입니다")
        }

        if window.pressFullScreenButton(), await confirmed(window) {
            return success(window, start: start, attempts: 2)
        }

        return .failed(
            expected: before ?? .zero,
            actual: window.currentFrame,
            reason: "전체화면 전환이 완료되지 않았습니다")
    }

    static func exit(_ window: AXWindow) async {
        guard window.isFullScreen else { return }
        window.setFullScreen(false)
        _ = await Polling.poll(timeout: transitionTimeout) {
            window.isFullScreen ? nil : true
        }
        _ = await Polling.settle(timeout: transitionTimeout) { window.currentFrame }
    }

    private static func confirmed(_ window: AXWindow) async -> Bool {
        let flagged = await Polling.poll(timeout: transitionTimeout) {
            window.isFullScreen ? true : nil
        }
        guard flagged == true else { return false }
        _ = await Polling.settle(timeout: transitionTimeout) { window.currentFrame }
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
