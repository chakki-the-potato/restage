import AppKit
import RestageKit

@MainActor
public struct HomeSpace {
    private let spaces: [String: Int]
    private let fallback: Int32?

    public static func capture() -> HomeSpace {
        var spaces: [String: Int] = [:]
        for entry in SpaceInventory.displays() ?? [] where entry.current > 0 {
            spaces[entry.display] = entry.current
        }
        return HomeSpace(spaces: spaces, fallback: spaces.isEmpty ? owner() : nil)
    }

    public func restore() {
        guard spaces.isEmpty else {
            for entry in SpaceInventory.displays() ?? [] {
                guard let wanted = spaces[entry.display], wanted != entry.current else { continue }
                SpaceInventory.show(space: wanted, on: entry.display)
            }
            return
        }
        guard let fallback, WindowInventory.onScreenWindowCount(pid: fallback) == 0 else { return }
        AXWindow.setApplicationFrontmost(pid: fallback)
    }

    private static func owner() -> Int32? {
        let owners = WindowInventory.onScreenOwners()
        let frontmost = NSWorkspace.shared.frontmostApplication?.processIdentifier
        if let frontmost, owners.contains(frontmost), livesOnlyHere(pid: frontmost) {
            return frontmost
        }
        return owners.first { livesOnlyHere(pid: $0) } ?? owners.first
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
