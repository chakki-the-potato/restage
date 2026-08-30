import CoreGraphics

@MainActor
public protocol WindowEngine {
    func launch(_ app: AppID) async throws -> ProcessHandle
    func waitForWindow(
        _ handle: ProcessHandle, selector: WindowSelector, timeout: Duration,
        mayFollowOtherSpaces: Bool, claim: Bool
    ) async throws -> WindowHandle
    func claim(pid: Int32, matching target: CGRect)
    func place(_ window: WindowHandle, slot: Slot, display: DisplayInfo) async -> PlacementResult
    func fullscreen(_ window: WindowHandle) async -> PlacementResult
}
