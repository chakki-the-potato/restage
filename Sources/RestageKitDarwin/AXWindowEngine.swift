import CoreGraphics
import RestageKit

@MainActor
public struct AXWindowEngine: WindowEngine {
    static let staleRetryTimeout: Duration = .seconds(10)

    private let claims = WindowClaims()

    public init() {}

    public func launch(_ app: AppID) async throws -> ProcessHandle {
        guard AccessibilityPermission.isTrusted() else {
            throw EngineError.accessibilityNotTrusted
        }
        let bundleID = try InstalledApps.bundleID(for: app)
        return try await AppLauncher.launch(bundleID: bundleID)
    }

    public func waitForWindow(
        _ handle: ProcessHandle, selector: WindowSelector, timeout: Duration,
        mayFollowOtherSpaces: Bool = false, claim: Bool = true
    ) async throws -> WindowHandle {
        try await WindowWaiter.wait(
            pid: handle.pid, timeout: timeout, selector: selector,
            mayFollowOtherSpaces: mayFollowOtherSpaces, claims: claim ? claims : nil)
    }

    public func claim(pid: Int32, matching target: CGRect) {
        guard let windows = try? AXWindow.windows(ofPID: pid) else { return }
        guard let window = windows.first(where: { window in
            guard let frame = window.currentFrame else { return false }
            return CurrentState.matches(frame, target)
        }) else { return }
        claims.claim(window)
    }

    public func place(
        _ window: WindowHandle, slot: Slot, display: DisplayInfo
    ) async -> PlacementResult {
        guard let axWindow = window as? AXWindow else {
            return .failed(expected: .zero, actual: nil, reason: L10n.string("error.window.unsupported_handle"))
        }
        let target = SlotGeometry.frame(
            for: slot, in: display.visibleFrame, primaryMaxY: display.primaryMaxY)
        let result = await placeOnce(axWindow, target: target)

        guard case .failed = result, axWindow.isStale else { return result }
        guard let fresh = try? await WindowWaiter.wait(
            pid: axWindow.pid, timeout: Self.staleRetryTimeout, claims: claims)
        else { return result }
        return await placeOnce(fresh, target: target)
    }

    private func placeOnce(_ window: AXWindow, target: CGRect) async -> PlacementResult {
        await WindowWaiter.prepareForDesktopPlacement(window)
        return await WindowPlacer.place(window, target: target)
    }

    public func fullscreen(_ window: WindowHandle) async -> PlacementResult {
        guard let axWindow = window as? AXWindow else {
            return .failed(expected: .zero, actual: nil, reason: L10n.string("error.window.unsupported_handle"))
        }
        return await FullScreenController.enter(axWindow)
    }

    public func exitFullscreen(_ window: WindowHandle) async -> Bool {
        guard let axWindow = window as? AXWindow else { return false }
        return await FullScreenController.exit(axWindow)
    }
}
