import AppKit

/// 화면 맨 위에서 메뉴바가 차지하는 띠.
///
/// 전체화면 앱 위에서 커서를 위로 올리면 시스템이 메뉴바를 꺼낸다. 그 순간 포커스가
/// 전체화면 앱으로 돌아가면서 우리 앱이 비활성이 되고 패널은 키를 잃는다. 누른 것이
/// 없으니 닫으면 안 되는데, 키를 잃었다는 사실만으로는 클릭과 구분되지 않는다.
///
/// 측정한 순서는 이렇다.
///
///     windowDidResignKey  menuShowing=false  appActive=false  keyWindow=nil
///     closePanel
///     NSApplicationDidResignActiveNotification
///
/// 앱이 비활성이 되는 것은 다른 앱을 눌렀을 때와 같아서 그것으로는 가를 수 없다.
/// 커서가 이 띠 안에 있는지로 가른다.
enum MenuBarZone {
    static func contains(_ point: CGPoint) -> Bool {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        guard let screen else { return false }
        return contains(
            point, in: screen.frame, visible: screen.visibleFrame,
            thickness: NSStatusBar.system.thickness)
    }

    /// 화면 값을 받아 판정한다. 실제 화면 없이도 시험할 수 있어야 한다.
    ///
    /// 띠의 두께는 화면 위쪽 여백에서 얻는다. 메뉴바가 숨어 있으면 그 여백이 0이 되므로
    /// 상태바 두께를 최소값으로 둔다. 메뉴바가 막 나타나는 중일 때도 판정이 흔들리지 않는다.
    static func contains(
        _ point: CGPoint, in frame: CGRect, visible: CGRect, thickness: CGFloat
    ) -> Bool {
        guard frame.minX <= point.x, point.x <= frame.maxX else { return false }
        let band = max(frame.maxY - visible.maxY, thickness)
        return point.y >= frame.maxY - band
    }
}
