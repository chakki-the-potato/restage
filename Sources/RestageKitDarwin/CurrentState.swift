import AppKit
import CoreGraphics
import RestageKit

/// 현재 창 상태를 Space와 무관하게 조회한다.
///
/// AX를 쓰지 않는 이유는 AX가 현재 Space의 창만 열거하기 때문이다. 전체화면 앱은
/// 전용 Space로 옮겨져 AX에서 사라지므로, AX로 판정하면 이미 목표를 달성한 앱을
/// "창 없음"으로 오판한다. `CGWindowList`는 Space와 무관하게 창을 본다.
@MainActor
public enum CurrentState {
    public static let tolerance: CGFloat = 2

    /// 목표 사각형과 일치하는 창이 있는지.
    public static func isPlaced(pid: Int32, target: CGRect) -> Bool {
        windowRects(pid: pid).contains { matches($0, target) }
    }

    /// 해당 디스플레이를 가득 채우는 창이 있는지. 전체화면 달성 판정에 쓴다.
    ///
    /// 크기만 보면 안 된다. 외장 디스플레이를 채운 창은 주 디스플레이보다 크므로,
    /// 크기만으로 판정하면 주 디스플레이 기준에서 전체화면으로 오판한다.
    /// 창이 그 디스플레이 위에 있는지까지 확인한다.
    ///
    /// 전체화면 창은 메뉴바 영역까지 덮어 `visibleFrame`보다 크므로 90% 기준을 쓴다.
    public static func isFullScreen(pid: Int32, on display: DisplayInfo) -> Bool {
        let bounds = axBounds(of: display)
        return windowRects(pid: pid).contains { rect in
            guard bounds.contains(CGPoint(x: rect.midX, y: rect.midY)) else { return false }
            return rect.width >= bounds.width * 0.9 && rect.height >= bounds.height * 0.9
        }
    }

    /// 디스플레이의 가용 영역을 AX 좌표계로 변환한다.
    private static func axBounds(of display: DisplayInfo) -> CGRect {
        let frame = display.visibleFrame
        return CGRect(
            x: frame.minX, y: display.primaryMaxY - frame.maxY,
            width: frame.width, height: frame.height)
    }

    /// 해당 프로세스가 가진 창의 개수. 0이 아닌데 AX가 못 보면 다른 Space에 있다는 뜻이다.
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
