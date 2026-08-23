import RestageKit

@MainActor
public enum WindowWaiter {
    /// 배치 가능한 창이 나타날 때까지 폴링한다.
    /// 조건: AXRole == AXWindow, 크기가 0보다 큼, 최소화 아님.
    /// 반환값은 AX 창 목록의 첫 번째, 즉 가장 최근 활성 창이다.
    public static func wait(pid: Int32, timeout: Duration) async throws -> AXWindow {
        var lastError: Error?

        let found = await Polling.poll(timeout: timeout) { () -> AXWindow? in
            do {
                let windows = try AXWindow.windows(ofPID: pid)
                return windows.first(where: isPlaceable)
            } catch {
                lastError = error
                return nil
            }
        }

        if let found { return found }
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

    private static func isPlaceable(_ window: AXWindow) -> Bool {
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
