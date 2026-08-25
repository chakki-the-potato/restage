import AppKit
import SwiftUI

enum PanelPalette {
    static let cardBackground = dynamic(light: 0.965, dark: 0.22)
    static let cardBorder = Color.primary.opacity(0.08)
    static let hoverTint = Color.accentColor.opacity(0.10)
    static let hoverBorder = Color.accentColor.opacity(0.22)
    static let warning = Color(nsColor: .systemOrange)

    static let iconRing = cardBackground

    private static func dynamic(light: CGFloat, dark: CGFloat) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(white: isDark ? dark : light, alpha: 1)
        })
    }
}
