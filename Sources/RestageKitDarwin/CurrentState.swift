import AppKit
import CoreGraphics
import RestageKit

@MainActor
public enum CurrentState {
    public static let tolerance: CGFloat = 2

    public static func isPlaced(pid: Int32, target: CGRect) -> Bool {
        windowRects(pid: pid).contains { matches($0, target) }
    }

    public static func isFullScreen(pid: Int32, on display: DisplayInfo) -> Bool {
        let bounds = display.axBounds
        return windowRects(pid: pid).contains { rect in
            guard bounds.contains(CGPoint(x: rect.midX, y: rect.midY)) else { return false }
            return rect.width >= bounds.width * 0.9 && rect.height >= bounds.height * 0.9
        }
    }

    public static func windowCount(pid: Int32) -> Int {
        windowRects(pid: pid).count
    }

    public static func matches(_ rect: CGRect, _ target: CGRect) -> Bool {
        abs(rect.minX - target.minX) <= tolerance
            && abs(rect.minY - target.minY) <= tolerance
            && abs(rect.width - target.width) <= tolerance
            && abs(rect.height - target.height) <= tolerance
    }

    private static func windowRects(pid: Int32) -> [CGRect] {
        let list = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { window in
            guard window[kCGWindowOwnerPID as String] as? Int32 == pid,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
                  let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double,
                  height > 50 else { return nil }
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }
}
