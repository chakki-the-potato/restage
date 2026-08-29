import CoreGraphics
import RestageKit

@MainActor
public enum WindowReveal {
    @discardableResult
    public static func raise(app name: String, frame: CGRect) -> Bool {
        guard let bundleID = try? InstalledApps.bundleID(for: AppID(name)),
              let running = AppLauncher.runningApplication(bundleID: bundleID),
              let windows = try? AXWindow.windows(ofPID: running.processIdentifier)
        else { return false }
        guard let window = windows.first(where: { window in
            guard let current = window.currentFrame else { return false }
            return CurrentState.matches(current, frame)
        }) else { return false }
        return window.raise()
    }
}
