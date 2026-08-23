import CoreGraphics
import RestageKit

@MainActor
public struct AXWindowEngine: WindowEngine {
    /// 창 요소가 무효화됐을 때 새 창을 다시 찾는 데 허용하는 시간.
    static let staleRetryTimeout: Duration = .seconds(10)

    public init() {}

    public func launch(_ app: AppID) async throws -> ProcessHandle {
        guard AccessibilityPermission.isTrusted() else {
            throw EngineError.accessibilityNotTrusted
        }
        let bundleID = try AppRegistry.bundleID(for: app)
        return try await AppLauncher.launch(bundleID: bundleID)
    }

    public func waitForWindow(
        _ handle: ProcessHandle, timeout: Duration
    ) async throws -> WindowHandle {
        try await WindowWaiter.wait(pid: handle.pid, timeout: timeout)
    }

    public func place(
        _ window: WindowHandle, slot: Slot, display: DisplayInfo
    ) async -> PlacementResult {
        guard let axWindow = window as? AXWindow else {
            return .failed(expected: .zero, actual: nil, reason: "지원하지 않는 WindowHandle 구현")
        }
        let target = SlotGeometry.frame(
            for: slot, in: display.visibleFrame, primaryMaxY: display.primaryMaxY)
        let result = await placeOnce(axWindow, target: target)

        guard case .failed = result, axWindow.isStale else { return result }
        guard let fresh = try? await WindowWaiter.wait(
            pid: axWindow.pid, timeout: Self.staleRetryTimeout) else { return result }
        return await placeOnce(fresh, target: target)
    }

    private func placeOnce(_ window: AXWindow, target: CGRect) async -> PlacementResult {
        await WindowWaiter.prepareForDesktopPlacement(window)
        return await WindowPlacer.place(window, target: target)
    }

    public func fullscreen(_ window: WindowHandle) async -> PlacementResult {
        guard let axWindow = window as? AXWindow else {
            return .failed(expected: .zero, actual: nil, reason: "지원하지 않는 WindowHandle 구현")
        }
        return await FullScreenController.enter(axWindow)
    }

    /// 전체화면을 해제하고 성공 여부를 반환한다. 실패하면 앱이 전용 Space에 남는다.
    public func exitFullscreen(_ window: WindowHandle) async -> Bool {
        guard let axWindow = window as? AXWindow else { return false }
        return await FullScreenController.exit(axWindow)
    }
}
