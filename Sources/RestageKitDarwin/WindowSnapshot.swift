import AppKit
import CoreGraphics
import RestageKit

public struct CapturedWindow: Sendable, Equatable {
    /// 설치된 앱의 표시 이름. config에 그대로 쓸 수 있는 값이다.
    public let appName: String
    public let bundleID: String
    public let title: String
    /// AX 좌표계 사각형.
    public let frame: CGRect
    /// 지금 보고 있는 데스크탑에 있는지. 아니면 다른 Space에 있거나 전체화면이다.
    public let isOnCurrentSpace: Bool
    /// 전용 데스크탑을 차지한 전체화면 창인지.
    public let isFullScreen: Bool

    public init(
        appName: String, bundleID: String, title: String, frame: CGRect,
        isOnCurrentSpace: Bool, isFullScreen: Bool = false
    ) {
        self.appName = appName
        self.bundleID = bundleID
        self.title = title
        self.frame = frame
        self.isOnCurrentSpace = isOnCurrentSpace
        self.isFullScreen = isFullScreen
    }
}

/// 지금 열려 있는 창을 읽는다. 현재 배치를 config로 옮길 때 출발점이 된다.
@MainActor
public enum WindowSnapshot {
    /// 도구 창이나 팔레트를 걸러내는 최소 크기.
    private static let minimumSide: CGFloat = 100

    /// 열려 있는 창 목록. 다른 데스크탑에 있는 창도 포함한다.
    ///
    /// AX가 아니라 `CGWindowList`로 읽는다. AX는 현재 Space의 창만 보여주므로 다른
    /// 데스크탑에 둔 창이 통째로 빠진다. `CGWindowList`는 Space와 무관하게 전부 보고,
    /// 위치·크기·제목을 함께 준다.
    ///
    /// 제목까지 나오는지는 이 컴퓨터에서 확인했다. 화면 기록 권한이 없어도 나왔다.
    /// 다만 항상 보장되지는 않아 빈 문자열이 올 수 있고, 그때는 창을 구분할 수 없다.
    public static func current() -> [CapturedWindow] {
        let apps = regularApps()
        let visible = onScreenWindowIDs()
        let displays = NSScreen.screens.map(\.frame)

        let all = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        return all.compactMap { window -> CapturedWindow? in
            guard let pid = window[kCGWindowOwnerPID as String] as? Int32,
                  let app = apps[pid],
                  window[kCGWindowLayer as String] as? Int == 0,
                  let frame = rect(from: window),
                  frame.width >= minimumSide, frame.height >= minimumSide else { return nil }

            let id = window[kCGWindowNumber as String] as? Int ?? -1
            let onCurrentSpace = visible.contains(id)
            return CapturedWindow(
                appName: app.name,
                bundleID: app.bundleID,
                title: (window[kCGWindowName as String] as? String) ?? "",
                frame: frame,
                isOnCurrentSpace: onCurrentSpace,
                isFullScreen: !onCurrentSpace && coversWholeDisplay(frame, displays))
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

    /// Dock에 아이콘이 있는 앱만 센다. 배경 도우미의 창은 사용자가 배치할 대상이 아니다.
    /// 자기 자신도 뺀다.
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

    /// 현재 데스크탑에 보이는 창의 번호. 이것과 대조해 다른 Space에 있는 창을 가려낸다.
    private static func onScreenWindowIDs() -> Set<Int> {
        let onScreen = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
            ?? []
        return Set(onScreen.compactMap { $0[kCGWindowNumber as String] as? Int })
    }

    /// 디스플레이 하나를 통째로 덮는 창인지. 전체화면 창은 메뉴바 자리까지 차지한다.
    ///
    /// 전용 데스크탑에 있으면서 화면을 꽉 채우면 전체화면으로 본다. 그냥 최대화한 창은
    /// 현재 데스크탑에 있으므로 여기까지 오지 않는다.
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
