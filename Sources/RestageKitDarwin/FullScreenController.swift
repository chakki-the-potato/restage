import CoreGraphics
import Foundation
import RestageKit

@MainActor
enum FullScreenController {
    static let transitionTimeout: Duration = .seconds(5)

    /// 속성 설정 후 창 크기가 실제로 바뀌기를 기다리는 시간.
    /// 실측 전환은 400ms 안에 끝난다. `AXFullScreen` 설정은 속성만 바꾸고
    /// 전환은 일으키지 않는 경우가 있어, 여기서 오래 기다리면 버튼 폴백이 그만큼 늦어진다.
    static let frameChangeTimeout: Duration = .seconds(2)

    static func enter(_ window: AXWindow) async -> PlacementResult {
        let before = window.currentFrame
        if window.isFullScreen {
            return .ok(actual: before ?? .zero, attempts: 0, elapsed: .zero, warnings: [])
        }

        let clock = ContinuousClock()
        let start = clock.now

        AXWindow.setApplicationFrontmost(pid: window.pid)

        if window.setFullScreen(true), await confirmed(window, changedFrom: before) {
            return success(window, start: start, attempts: 1)
        }

        if window.isFullScreen { window.setFullScreen(false) }
        _ = await Polling.poll(timeout: frameChangeTimeout) {
            window.isFullScreen ? nil : true
        }

        guard window.hasFullScreenButton else {
            return .constrained(
                actual: window.currentFrame ?? .zero,
                expected: before ?? .zero,
                reason: "전체화면을 지원하지 않는 창입니다")
        }

        if window.pressFullScreenButton(), await confirmed(window, changedFrom: before) {
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

    /// 전환 전에 앱을 최전면으로 올린다. 최전면이 아니면 `AXFullScreen` 설정이
    /// 성공으로 보고되고 속성도 true가 되지만 실제 전환은 일어나지 않는다.
    /// 콜드 스타트는 창 대기 단계의 활성화 폴백 덕에 우연히 통과하고
    /// 웜 스타트만 실패해서, 원인을 가리기 쉬운 형태로 드러난다.
    ///
    /// `AXFullScreen`이 true가 된 뒤 창 크기가 실제로 바뀌고 안정될 때까지 기다린다.
    ///
    /// 속성만 보고 끝내면 안 된다. 전환 애니메이션이 시작되기 전에는 이전 크기가 그대로
    /// 조회되고, 25ms 간격 두 샘플이 모두 그 값이면 안정된 것으로 오판한다. 그러면
    /// 전체화면이 됐다고 보고하면서 실측값은 이전 크기를 싣는 모순이 생긴다.
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
