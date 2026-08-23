import CoreGraphics
import Foundation
import RestageKit

@MainActor
public enum WindowPlacer {
    static let tolerance: CGFloat = 2
    static let maxAttempts = 3
    static let totalTimeout: Duration = .seconds(3)
    static let settleTimeout: Duration = .milliseconds(800)

    public static func place(_ window: AXWindow, target: CGRect) async -> PlacementResult {
        let clock = ContinuousClock()
        let start = clock.now
        let deadline = start.advanced(by: totalTimeout)
        var lastObserved: CGRect?

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
                    warnings.append("다른 Space에 있어 화면에 보이지 않습니다")
                }
                return .ok(
                    actual: settled,
                    attempts: attempt,
                    elapsed: start.duration(to: clock.now),
                    warnings: warnings)
            }

            if clock.now >= deadline { break }
        }

        return classifyFailure(window, target: target, observed: lastObserved)
    }

    /// 적용 순서. 멀티 디스플레이 지원 시 position → size → position 3단으로 교체한다.
    /// 지금은 주 디스플레이만 다루므로 화면 경계 clamp가 발생하지 않는다.
    private static func apply(_ target: CGRect, to window: AXWindow) {
        window.setPosition(target.origin)
        window.setSize(target.size)
    }

    private static func matches(_ actual: CGRect, _ target: CGRect) -> Bool {
        abs(actual.minX - target.minX) <= tolerance
            && abs(actual.minY - target.minY) <= tolerance
            && abs(actual.width - target.width) <= tolerance
            && abs(actual.height - target.height) <= tolerance
    }

    /// 도달 실패의 원인이 앱의 최소 크기 제약인지 판별한다.
    /// 제약이 원인이면 고칠 수 없는 것이므로 실패가 아니라 constrained로 분류한다.
    private static func classifyFailure(
        _ window: AXWindow, target: CGRect, observed: CGRect?
    ) -> PlacementResult {
        guard let observed else {
            return .failed(expected: target, actual: nil, reason: "창 좌표를 조회할 수 없습니다")
        }

        if let minSize = window.minSize {
            let widthBlocked = target.width < minSize.width - tolerance
            let heightBlocked = target.height < minSize.height - tolerance
            let widthSettledAtMin = abs(observed.width - minSize.width) <= tolerance
            let heightSettledAtMin = abs(observed.height - minSize.height) <= tolerance

            if (widthBlocked && widthSettledAtMin) || (heightBlocked && heightSettledAtMin) {
                return .constrained(actual: observed, expected: target, minSize: minSize)
            }
        }

        return .failed(
            expected: target,
            actual: observed,
            reason: "\(maxAttempts)회 시도 후에도 목표 좌표에 도달하지 못했습니다")
    }
}
