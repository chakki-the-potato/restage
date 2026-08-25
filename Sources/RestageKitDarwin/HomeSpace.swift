import AppKit
import RestageKit

@MainActor
public enum HomeSpace {
    public static func capture() -> Int32? {
        let owners = WindowInventory.onScreenOwners()
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if let frontmost, owners.contains(frontmost), livesOnlyHere(pid: frontmost) {
            return frontmost
        }
        return owners.first { livesOnlyHere(pid: $0) } ?? owners.first
    }

    public static func returnTo(_ pid: Int32) {
        AXWindow.setApplicationFrontmost(pid: pid)
    }

    private static func livesOnlyHere(pid: Int32) -> Bool {
        livesOnlyHere(
            here: WindowInventory.onScreenWindowCount(pid: pid),
            total: WindowInventory.windowCount(pid: pid))
    }

    public static func livesOnlyHere(here: Int, total: Int) -> Bool {
        here > 0 && here == total
    }
}
