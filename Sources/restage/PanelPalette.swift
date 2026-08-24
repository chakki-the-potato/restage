import AppKit
import SwiftUI

/// 패널이 쓰는 색.
///
/// 시스템 색만으로는 부족한 자리가 있다. 카드 배경이 그렇다. `controlBackgroundColor`는
/// 라이트에서 흰색이라 흰 패널 위에서 사라진다. 여기서만 밝기를 정하고 다크 값을 짝지어
/// 둔다. 아이콘 테두리처럼 카드와 같은 색이어야 하는 곳도 이 값을 가져다 쓴다.
enum PanelPalette {
    static let cardBackground = dynamic(light: 0.965, dark: 0.22)
    static let cardBorder = Color.primary.opacity(0.08)
    static let hoverTint = Color.accentColor.opacity(0.10)
    static let hoverBorder = Color.accentColor.opacity(0.22)
    static let warning = Color(nsColor: .systemOrange)

    /// 카드와 같은 색으로 칠하는 아이콘 테두리. 겹친 아이콘 사이를 띄워 보이게 한다.
    static let iconRing = cardBackground

    private static func dynamic(light: CGFloat, dark: CGFloat) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(white: isDark ? dark : light, alpha: 1)
        })
    }
}
