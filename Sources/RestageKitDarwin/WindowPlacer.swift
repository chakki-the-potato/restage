import CoreGraphics
import Foundation
import RestageKit

@MainActor
public enum WindowPlacer {
    static let tolerance: CGFloat = 2
    /// 시도 횟수가 아니라 `totalTimeout`이 주 제약이다. Electron 앱은 기동 중
    /// 자기 크기를 반복해서 되돌리는데, 한 번 시도가 수십 ms라 횟수를 낮게 잡으면
    /// 앱이 진정되기 전에 루프가 먼저 끝난다.
    static let maxAttempts = 40
    static let totalTimeout: Duration = .seconds(8)
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

    /// position → size → position 3단 적용.
    ///
    /// 크기부터 적용하면 창이 아직 원래 디스플레이에 있어 그 화면 경계로 clamp된다.
    /// 첫 position으로 목표 화면에 진입시키고, size를 적용한 뒤, size 적용 중 밀린
    /// position을 다시 맞춘다. 단일 디스플레이에서는 2단 적용과 결과가 같다.
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

    /// 도달 실패의 원인이 앱이 허용하지 않는 것인지 판별한다.
    /// 앱이 막은 것이면 고칠 수 없으므로 실패가 아니라 constrained로 분류한다.
    private static func classifyFailure(
        _ window: AXWindow, target: CGRect, observed: CGRect?
    ) -> PlacementResult {
        guard let observed else {
            return .failed(expected: target, actual: nil, reason: "창 좌표를 조회할 수 없습니다")
        }

        if window.isFullScreen {
            return .constrained(
                actual: observed, expected: target,
                reason: "전체화면 상태라 배치할 수 없습니다 (AX로 해제 불가, ctrl+cmd+F로 직접 해제)")
        }

        if !window.isSizeSettable {
            return .constrained(
                actual: observed, expected: target, reason: "크기를 바꿀 수 없는 창입니다")
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
            reason: "\(maxAttempts)회 시도 후에도 목표 좌표에 도달하지 못했습니다")
    }

    /// 앱이 `AXMinSize`로 최소 크기를 알려주는 경우.
    private static func declaredMinimumReason(
        target: CGRect, observed: CGRect, minSize: CGSize
    ) -> String? {
        let widthBlocked = target.width < minSize.width - tolerance
        let heightBlocked = target.height < minSize.height - tolerance
        let widthSettledAtMin = abs(observed.width - minSize.width) <= tolerance
        let heightSettledAtMin = abs(observed.height - minSize.height) <= tolerance

        guard (widthBlocked && widthSettledAtMin) || (heightBlocked && heightSettledAtMin)
        else { return nil }
        return "최소 크기 \(Int(minSize.width))x\(Int(minSize.height))"
    }

    /// `AXMinSize`를 노출하지 않으면서 최소 크기를 강제하는 앱을 동작으로 판별한다.
    ///
    /// Xcode가 그렇다. `AXMinSize` 조회가 -25205(속성 미지원)를 반환하는데 너비는 940
    /// 아래로 내려가지 않는다. 높이는 요청대로 바뀌므로 리사이즈 자체를 거부하는 것은 아니다.
    ///
    /// 판별 근거는 "한 축은 요청대로 맞았는데 다른 축만 요청보다 크게 고정된" 상태다.
    /// 한 축이 맞았다는 것은 앱이 크기 변경을 받아들였다는 뜻이므로, 남은 축의 차이는
    /// 우리가 못 맞춘 것이 아니라 앱이 막은 것이다.
    ///
    /// 위치가 목표와 다르면 판별하지 않는다. 위치까지 어긋났다는 것은 크기 제약이 아니라
    /// 다른 문제(전체화면, 다른 Space 등)라는 뜻이고, 그때 최소 크기라고 보고하면
    /// 원인을 감추는 잘못된 사유가 된다.
    private static func inferredMinimumReason(target: CGRect, observed: CGRect) -> String? {
        guard abs(observed.minX - target.minX) <= tolerance,
              abs(observed.minY - target.minY) <= tolerance else { return nil }

        let widthStuckLarger = observed.width > target.width + tolerance
        let heightStuckLarger = observed.height > target.height + tolerance
        let widthMatches = abs(observed.width - target.width) <= tolerance
        let heightMatches = abs(observed.height - target.height) <= tolerance

        if widthStuckLarger && heightMatches {
            return "최소 너비 \(Int(observed.width)) (앱이 AXMinSize를 노출하지 않음)"
        }
        if heightStuckLarger && widthMatches {
            return "최소 높이 \(Int(observed.height)) (앱이 AXMinSize를 노출하지 않음)"
        }
        if widthStuckLarger && heightStuckLarger {
            return "최소 크기 \(Int(observed.width))x\(Int(observed.height)) (앱이 AXMinSize를 노출하지 않음)"
        }
        return nil
    }
}
