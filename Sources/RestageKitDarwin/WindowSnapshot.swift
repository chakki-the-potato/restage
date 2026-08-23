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

    public init(appName: String, bundleID: String, title: String, frame: CGRect) {
        self.appName = appName
        self.bundleID = bundleID
        self.title = title
        self.frame = frame
    }
}

/// 지금 열려 있는 창을 읽는다. 현재 배치를 config로 옮길 때 출발점이 된다.
@MainActor
public enum WindowSnapshot {
    /// 도구 창이나 팔레트를 걸러내는 최소 크기.
    private static let minimumSide: CGFloat = 100

    /// 현재 Space에 보이는 창 목록.
    ///
    /// AX로 읽는 이유는 창 제목 때문이다. `CGWindowList`로도 창을 볼 수 있지만 제목을
    /// 얻으려면 화면 기록 권한이 따로 필요하다. AX는 이미 받은 접근성 권한만으로 제목까지 읽는다.
    ///
    /// 대신 AX는 현재 Space의 창만 본다. 다른 Space나 전체화면으로 넘어간 창은 여기 없다.
    /// 이 제약은 호출자가 사용자에게 알려야 한다.
    public static func current() throws -> [CapturedWindow] {
        let selfPID = ProcessInfo.processInfo.processIdentifier
        var captured: [CapturedWindow] = []

        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular
            && !app.isTerminated
            && app.processIdentifier != selfPID {
            guard let bundleID = app.bundleIdentifier else { continue }
            let name = InstalledApps.displayName(bundleID: bundleID)
                ?? app.localizedName ?? bundleID

            for window in try AXWindow.windows(ofPID: app.processIdentifier) {
                guard window.role == AXAttributes.windowRole,
                      !window.isMinimized,
                      let frame = window.currentFrame,
                      frame.width >= minimumSide, frame.height >= minimumSide else { continue }
                captured.append(
                    CapturedWindow(
                        appName: name, bundleID: bundleID,
                        title: window.title ?? "", frame: frame))
            }
        }

        return captured.sorted { lhs, rhs in
            if lhs.frame.minX != rhs.frame.minX { return lhs.frame.minX < rhs.frame.minX }
            if lhs.frame.minY != rhs.frame.minY { return lhs.frame.minY < rhs.frame.minY }
            return lhs.appName < rhs.appName
        }
    }
}
