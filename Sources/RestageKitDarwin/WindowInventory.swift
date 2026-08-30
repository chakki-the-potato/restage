import AppKit
import CoreGraphics

enum WindowInventory {
    private static let minimumSide: CGFloat = 100

    static func windowCount(pid: Int32) -> Int {
        rects(pid: pid, options: [.optionAll, .excludeDesktopElements]).count
    }

    static func census(pid: Int32) -> WindowCensus.Result? {
        guard let currentSpaces = SpaceInventory.currentSpaceIDs() else { return nil }
        var windows: [WindowCensus.Window] = []
        for window in entries(pid: pid, options: [.optionAll, .excludeDesktopElements]) {
            guard let number = window[kCGWindowNumber as String] as? Int,
                  let frame = bounds(of: window) else { continue }
            windows.append(
                WindowCensus.Window(
                    number: number, frame: frame,
                    spaces: SpaceInventory.spaces(ofWindow: number) ?? []))
        }
        return WindowCensus.classify(
            windows, currentSpaces: currentSpaces, displays: displayBounds())
    }

    static func spaceOfWindowElsewhere(pid: Int32) -> Int? {
        guard let census = census(pid: pid), let number = census.elsewhere.first else { return nil }
        return SpaceInventory.spaces(ofWindow: number)?.first
    }

    static func hereCount(pid: Int32) -> Int {
        census(pid: pid)?.here.count ?? onScreenWindowCount(pid: pid)
    }

    static func unhide(pid: Int32) {
        guard let running = NSRunningApplication(processIdentifier: pid), running.isHidden
        else { return }
        running.unhide()
    }

    static func onScreenWindowCount(pid: Int32) -> Int {
        rects(pid: pid, options: [.optionOnScreenOnly, .excludeDesktopElements]).count
    }

    static func offDisplayWindowCount(pid: Int32) -> Int {
        let displays = displayBounds()
        return rects(pid: pid, options: [.optionAll, .excludeDesktopElements])
            .filter { rect in !displays.contains { $0.intersects(rect) } }
            .count
    }

    static func onScreenOwners() -> [Int32] {
        let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        var seen: Set<Int32> = []
        var owners: [Int32] = []
        for window in list {
            guard let pid = window[kCGWindowOwnerPID as String] as? Int32,
                  isRealWindow(window), seen.insert(pid).inserted
            else { continue }
            owners.append(pid)
        }
        return owners
    }

    private static func rects(pid: Int32, options: CGWindowListOption) -> [CGRect] {
        entries(pid: pid, options: options).compactMap(bounds(of:))
    }

    private static func entries(
        pid: Int32, options: CGWindowListOption
    ) -> [[String: Any]] {
        let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        return list.filter {
            $0[kCGWindowOwnerPID as String] as? Int32 == pid && isRealWindow($0)
        }
    }

    private static func isRealWindow(_ window: [String: Any]) -> Bool {
        guard window[kCGWindowLayer as String] as? Int == 0,
              (window[kCGWindowAlpha as String] as? Double ?? 1) > 0,
              let rect = bounds(of: window)
        else { return false }
        return rect.width > minimumSide && rect.height > minimumSide
    }

    private static func bounds(of window: [String: Any]) -> CGRect? {
        guard let raw = window[kCGWindowBounds as String] as? [String: Any],
              let x = raw["X"] as? Double, let y = raw["Y"] as? Double,
              let width = raw["Width"] as? Double, let height = raw["Height"] as? Double
        else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func displayBounds() -> [CGRect] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { CGDisplayBounds($0) }
    }
}
