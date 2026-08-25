import AppKit
import CoreGraphics

enum WindowInventory {
    private static let minimumHeight: CGFloat = 50

    static func windowCount(pid: Int32) -> Int {
        let list = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.filter { window in
            guard window[kCGWindowOwnerPID as String] as? Int32 == pid,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let height = bounds["Height"] as? Double else { return false }
            return CGFloat(height) > minimumHeight
        }.count
    }
}
