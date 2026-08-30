import AppKit
import CoreGraphics
import RestageKit

public struct CapturedWindow: Sendable, Equatable {
    public let appName: String
    public let bundleID: String
    public let title: String
    public let frame: CGRect
    public let isOnCurrentSpace: Bool
    public let isFullScreen: Bool
    public let isSharedFullScreen: Bool

    public init(
        appName: String, bundleID: String, title: String, frame: CGRect,
        isOnCurrentSpace: Bool, isFullScreen: Bool = false, isSharedFullScreen: Bool = false
    ) {
        self.appName = appName
        self.bundleID = bundleID
        self.title = title
        self.frame = frame
        self.isOnCurrentSpace = isOnCurrentSpace
        self.isFullScreen = isFullScreen
        self.isSharedFullScreen = isSharedFullScreen
    }
}

@MainActor
public enum WindowSnapshot {
    private static let minimumSide: CGFloat = 100

    public static func current() -> [CapturedWindow] {
        let apps = regularApps()
        let visible = onScreenWindowIDs()
        let displays = NSScreen.screens.map(\.frame)
        let bounds = WindowInventory.displayBounds()
        let map = SpaceInventory.map()

        let all = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        return all.compactMap { window -> CapturedWindow? in
            guard let pid = window[kCGWindowOwnerPID as String] as? Int32,
                  let app = apps[pid],
                  window[kCGWindowLayer as String] as? Int == 0,
                  let frame = rect(from: window),
                  frame.width >= minimumSide, frame.height >= minimumSide else { return nil }

            let id = window[kCGWindowNumber as String] as? Int ?? -1
            guard let map else {
                let onCurrentSpace = visible.contains(id)
                return CapturedWindow(
                    appName: app.name, bundleID: app.bundleID,
                    title: (window[kCGWindowName as String] as? String) ?? "",
                    frame: frame, isOnCurrentSpace: onCurrentSpace,
                    isFullScreen: !onCurrentSpace && coversWholeDisplay(frame, displays))
            }

            let spaces = SpaceInventory.spaces(ofWindow: id) ?? []
            guard !spaces.isEmpty,
                  bounds.contains(where: { $0.intersects(frame) }),
                  map.holdsAllOf(spaces, window: id) else { return nil }

            return CapturedWindow(
                appName: app.name,
                bundleID: app.bundleID,
                title: (window[kCGWindowName as String] as? String) ?? "",
                frame: frame,
                isOnCurrentSpace: map.isCurrent(spaces),
                isFullScreen: map.isFullScreen(spaces),
                isSharedFullScreen: map.isSharedFullScreen(spaces))
        }
        .sorted { lhs, rhs in
            if lhs.isOnCurrentSpace != rhs.isOnCurrentSpace { return lhs.isOnCurrentSpace }
            if lhs.frame.minX != rhs.frame.minX { return lhs.frame.minX < rhs.frame.minX }
            if lhs.frame.minY != rhs.frame.minY { return lhs.frame.minY < rhs.frame.minY }
            return lhs.appName < rhs.appName
        }
    }

    private struct AppInfo {
        let name: String
        let bundleID: String
    }

    private static func regularApps() -> [Int32: AppInfo] {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        var result: [Int32: AppInfo] = [:]
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular
            && !app.isTerminated
            && app.processIdentifier != selfPID {
            guard let bundleID = app.bundleIdentifier else { continue }
            let name = InstalledApps.displayName(bundleID: bundleID)
                ?? app.localizedName ?? bundleID
            result[app.processIdentifier] = AppInfo(name: name, bundleID: bundleID)
        }
        return result
    }

    private static func onScreenWindowIDs() -> Set<Int> {
        let onScreen = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
            ?? []
        return Set(onScreen.compactMap { $0[kCGWindowNumber as String] as? Int })
    }

    private static func coversWholeDisplay(_ frame: CGRect, _ displays: [CGRect]) -> Bool {
        displays.contains { display in
            abs(frame.width - display.width) <= fullScreenTolerance
                && abs(frame.height - display.height) <= fullScreenTolerance
        }
    }

    private static let fullScreenTolerance: CGFloat = 4

    private static func rect(from window: [String: Any]) -> CGRect? {
        guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
              let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
              let width = bounds["Width"] as? Double,
              let height = bounds["Height"] as? Double else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
