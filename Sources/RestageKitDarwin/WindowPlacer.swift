import CoreGraphics
import Foundation
import RestageKit

@MainActor
public enum WindowPlacer {
    static let tolerance: CGFloat = 2
    static let maxAttempts = 40
    static let totalTimeout: Duration = .seconds(8)
    static let settleTimeout: Duration = .milliseconds(800)

    public static func place(_ window: AXWindow, target: CGRect) async -> PlacementResult {
        let clock = ContinuousClock()
        let start = clock.now
        let deadline = start.advanced(by: totalTimeout)
        var lastObserved: CGRect?
        var previous: CGRect?

        for attempt in 1...maxAttempts {
            apply(target, to: window)

            let settled = await Polling.settle(timeout: settleTimeout) { window.currentFrame }
            lastObserved = settled

            guard let settled else {
                if clock.now >= deadline { break }
                continue
            }

            if matches(settled, target) {
                var warnings: [String] = []
                if !window.isOnActiveSpace {
                    warnings.append(L10n.string("warn.other_space"))
                }
                return .ok(
                    actual: settled,
                    attempts: attempt,
                    elapsed: start.duration(to: clock.now),
                    warnings: warnings)
            }

            if settled == previous {
                return classifyFailure(window, target: target, observed: settled)
            }
            previous = settled

            if clock.now >= deadline { break }
        }

        return classifyFailure(window, target: target, observed: lastObserved)
    }

    private static func apply(_ target: CGRect, to window: AXWindow) {
        window.setPosition(target.origin)
        window.setSize(target.size)
        window.setPosition(target.origin)
    }

    private static func matches(_ actual: CGRect, _ target: CGRect) -> Bool {
        abs(actual.minX - target.minX) <= tolerance
            && abs(actual.minY - target.minY) <= tolerance
            && abs(actual.width - target.width) <= tolerance
            && abs(actual.height - target.height) <= tolerance
    }

    private static func classifyFailure(
        _ window: AXWindow, target: CGRect, observed: CGRect?
    ) -> PlacementResult {
        guard let observed else {
            return .failed(expected: target, actual: nil, reason: L10n.string("error.place.no_frame"))
        }

        if window.isFullScreen {
            return .constrained(
                actual: observed, expected: target,
                reason: L10n.string("error.place.fullscreen_blocked"))
        }

        if !window.isSizeSettable {
            return .constrained(
                actual: observed, expected: target, reason: L10n.string("error.place.not_resizable"))
        }

        if let minSize = window.minSize,
           let reason = declaredMinimumReason(target: target, observed: observed, minSize: minSize) {
            return .constrained(actual: observed, expected: target, reason: reason)
        }

        if let reason = inferredMinimumReason(target: target, observed: observed) {
            return .constrained(actual: observed, expected: target, reason: reason)
        }

        return .failed(
            expected: target,
            actual: observed,
            reason: L10n.string("error.place.retries_exhausted", maxAttempts))
    }

    private static func declaredMinimumReason(
        target: CGRect, observed: CGRect, minSize: CGSize
    ) -> String? {
        let widthBlocked = target.width < minSize.width - tolerance
        let heightBlocked = target.height < minSize.height - tolerance
        let widthSettledAtMin = abs(observed.width - minSize.width) <= tolerance
        let heightSettledAtMin = abs(observed.height - minSize.height) <= tolerance

        guard (widthBlocked && widthSettledAtMin) || (heightBlocked && heightSettledAtMin)
        else { return nil }
        return L10n.string("constraint.min_size", Int(minSize.width), Int(minSize.height))
    }

    private static func inferredMinimumReason(target: CGRect, observed: CGRect) -> String? {
        guard abs(observed.minX - target.minX) <= tolerance,
              abs(observed.minY - target.minY) <= tolerance else { return nil }

        let widthStuckLarger = observed.width > target.width + tolerance
        let heightStuckLarger = observed.height > target.height + tolerance
        let widthMatches = abs(observed.width - target.width) <= tolerance
        let heightMatches = abs(observed.height - target.height) <= tolerance

        if widthStuckLarger && heightMatches {
            return L10n.string("constraint.min_width_unexposed", Int(observed.width))
        }
        if heightStuckLarger && widthMatches {
            return L10n.string("constraint.min_height_unexposed", Int(observed.height))
        }
        if widthStuckLarger && heightStuckLarger {
            return L10n.string("constraint.min_size_unexposed", Int(observed.width), Int(observed.height))
        }
        return nil
    }
}
