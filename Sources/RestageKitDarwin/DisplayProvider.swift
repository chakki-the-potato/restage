import AppKit
import RestageKit

@MainActor
public enum DisplayProvider {
    /// 주 디스플레이 정보. 멀티 디스플레이 선택은 후속 사이클에서 추가한다.
    public static func primary() -> DisplayInfo? {
        guard let main = NSScreen.main, let first = NSScreen.screens.first else { return nil }
        return DisplayInfo(visibleFrame: main.visibleFrame, primaryMaxY: first.frame.maxY)
    }
}
