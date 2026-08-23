import RestageKit

@MainActor
public enum WindowWaiter {
    /// 활성화 폴백을 발동하기까지 기다리는 시간.
    static let activationGrace: Duration = .milliseconds(750)

    /// 크기 고정 창만 보일 때 그것을 최종 후보로 받아들이기까지 기다리는 시간.
    /// 스플래시가 본창으로 교체되는 시간을 벌어준다. 실측상 Discord는 3초 안에 교체된다.
    static let splashGrace: Duration = .seconds(4)

    /// 배치 가능한 창이 나타날 때까지 폴링한다.
    /// 조건: AXRole == AXWindow, 크기가 0보다 큼, 최소화 아님.
    /// 반환값은 AX 창 목록의 첫 번째, 즉 가장 최근 활성 창이다.
    ///
    /// 일부 앱은 최전면이 되기 전까지 AX 창 트리를 만들지 않는다. Safari가 그렇다.
    /// 창이 실제로 열려 있고 화면에 보이는데도 `AXWindows`가 빈 배열을 돌려준다.
    /// 그래서 `activationGrace` 안에 창을 못 찾으면 한 번만 앱을 활성화하고 계속 폴링한다.
    /// 활성화를 처음부터 하지 않는 이유는 배치 도중 앱들이 서로 포커스를 뺏으면
    /// 마지막에 지정 앱으로 포커스를 주는 동작과 충돌하기 때문이다.
    public static func wait(pid: Int32, timeout: Duration) async throws -> AXWindow {
        var lastError: Error?
        var fixedSizeCandidate: AXWindow?
        var fixedSizeSeenAt: ContinuousClock.Instant?
        var activated = false
        let clock = ContinuousClock()
        let activationDeadline = clock.now.advanced(by: activationGrace)

        let found = await Polling.poll(timeout: timeout) { () -> AXWindow? in
            do {
                let windows = try AXWindow.windows(ofPID: pid)
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
        throw EngineError.windowTimeout(pid: pid, seconds: seconds(of: timeout))
    }

    /// 배치 전 창 상태를 정리한다. 최소화 해제, 필요 시 전체화면 해제.
    /// 크기가 안정될 때까지 기다린 뒤 반환한다.
    public static func prepareForDesktopPlacement(_ window: AXWindow) async {
        if window.isMinimized {
            window.setMinimized(false)
            _ = await Polling.settle(timeout: .seconds(2)) { window.currentFrame }
        }
        if window.isFullScreen {
            window.setFullScreen(false)
            _ = await Polling.settle(timeout: .seconds(3)) { window.currentFrame }
        }
    }

    /// 크기까지 바꿀 수 있는 창. 배치 대상으로 우선 선택한다.
    ///
    /// 크기 변경 가능 여부를 조건에 넣은 이유는 Electron 앱의 스플래시 창 때문이다.
    /// Discord는 기동 직후 300x300 고정 크기 창을 먼저 띄우고 잠시 뒤 1280x870 본창으로
    /// 교체한다. 이 조건이 없으면 스플래시를 잡아 위치만 옮기고 크기는 실패한다.
    private static func isPlaceable(_ window: AXWindow) -> Bool {
        isRealWindow(window) && window.isSizeSettable
    }

    /// 크기 고정 여부와 무관한 실제 창. 타임아웃 시 폴백으로 쓴다.
    ///
    /// IINA의 시작 창처럼 앱이 가진 창이 전부 크기 고정인 경우가 있다. 그때 아무것도
    /// 반환하지 않으면 "창이 없다"는 잘못된 보고가 나가므로, 이 창을 넘겨서
    /// 배치 단계가 크기 제약을 사유로 CONSTRAINED를 내도록 한다.
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
