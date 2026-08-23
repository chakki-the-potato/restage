import AppKit
import CoreGraphics

/// AX와 무관하게 창의 존재만 확인한다.
///
/// AX는 현재 Space의 창만 열거하므로, 다른 Space에 있는 창은 "없는 것"과 구별되지 않는다.
/// `CGWindowList`는 Space와 무관하게 전체를 보므로 둘을 대조하면 구별할 수 있다.
/// 이 구별이 없으면 전체화면으로 다른 Space에 가 있는 앱이 "창이 뜨지 않았습니다"로
/// 보고되어, 사용자가 원인을 찾을 단서를 얻지 못한다.
enum WindowInventory {
    private static let minimumHeight: CGFloat = 50

    static func windowCount(pid: Int32) -> Int {
        let list = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.filter { window in
            guard window[kCGWindowOwnerPID as String] as? Int32 == pid,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let height = bounds["Height"] as? Double else { return false }
            return CGFloat(height) > minimumHeight
        }.count
    }
}
