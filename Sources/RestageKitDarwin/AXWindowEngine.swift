import CoreGraphics
import RestageKit

@MainActor
public struct AXWindowEngine: WindowEngine {
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
        await WindowWaiter.prepareForDesktopPlacement(axWindow)
        let target = SlotGeometry.frame(
            for: slot, in: display.visibleFrame, primaryMaxY: display.primaryMaxY)
        return await WindowPlacer.place(axWindow, target: target)
    }

    public func fullscreen(_ window: WindowHandle) async -> PlacementResult {
        .failed(expected: .zero, actual: nil, reason: "미구현")
    }
}
