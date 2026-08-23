import AppKit
import RestageKit

@MainActor
public enum DisplayProvider {
    /// 주 디스플레이 정보. 멀티 디스플레이 선택은 후속 사이클에서 추가한다.
    ///
    /// `NSScreen.main`을 쓰지 않는 이유: 그것은 주 디스플레이가 아니라 키보드 포커스가
    /// 있는 화면이라 실행 시점마다 값이 달라진다. `screens.first`가 메뉴바를 가진
    /// 주 디스플레이이며, AX 좌표계의 원점 기준이기도 하다.
    public static func primary() -> DisplayInfo? {
        guard let primary = NSScreen.screens.first else { return nil }
        return DisplayInfo(visibleFrame: primary.visibleFrame, primaryMaxY: primary.frame.maxY)
    }
}
