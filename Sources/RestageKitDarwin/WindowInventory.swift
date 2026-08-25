import AppKit
import CoreGraphics

enum WindowInventory {
    private static let minimumHeight: CGFloat = 50

    static func windowCount(pid: Int32) -> Int {
        count(pid: pid, options: [.optionAll, .excludeDesktopElements])
    }

    static func onScreenWindowCount(pid: Int32) -> Int {
        count(pid: pid, options: [.optionOnScreenOnly, .excludeDesktopElements])
    }

    private static func count(pid: Int32, options: CGWindowListOption) -> Int {
        let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return list.filter { window in
            guard window[kCGWindowOwnerPID as String] as? Int32 == pid,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let height = bounds["Height"] as? Double else { return false }
            return CGFloat(height) > minimumHeight
        }.count
    }
}
