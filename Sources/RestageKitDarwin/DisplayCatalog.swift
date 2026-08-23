import AppKit
import RestageKit

@MainActor
public enum DisplayCatalog {
    /// 사용 가능한 디스플레이 목록.
    ///
    /// 외장 디스플레이는 프레임 원점 기준으로 정렬한다. `NSScreen.screens`의 배열 순서를
    /// 그대로 쓰면 재부팅이나 연결 순서에 따라 `external-1`이 가리키는 화면이 바뀐다.
    ///
    /// `primaryMaxY`는 모든 디스플레이에서 주 디스플레이의 값을 쓴다. AX 좌표계의 원점이
    /// 주 디스플레이 좌상단이므로, 외장 디스플레이의 좌표도 같은 기준으로 변환해야 한다.
    /// `AppKitBootstrap.ensureGUIApplication()`이 먼저 호출되어 있어야 한다.
    /// 그렇지 않으면 보조 디스플레이의 `visibleFrame`이 메뉴바를 반영하지 않는다.
    public static func current() -> DisplayList? {
        AppKitBootstrap.ensureGUIApplication()
        let screens = NSScreen.screens
        guard let primaryScreen = screens.first else { return nil }
        let primaryMaxY = primaryScreen.frame.maxY

        let primary = DisplayInfo(
            visibleFrame: primaryScreen.visibleFrame, primaryMaxY: primaryMaxY)

        let externals = screens.dropFirst()
            .sorted { lhs, rhs in
                if lhs.frame.minX != rhs.frame.minX { return lhs.frame.minX < rhs.frame.minX }
                return lhs.frame.minY < rhs.frame.minY
            }
            .map { DisplayInfo(visibleFrame: $0.visibleFrame, primaryMaxY: primaryMaxY) }

        return DisplayList(primary: primary, externals: externals)
    }
}
