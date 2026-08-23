import AppKit

/// 메뉴바 상태 항목에 쓰는 아이콘.
///
/// template으로 표시하면 라이트/다크 메뉴바와 클릭 하이라이트에 맞춰 시스템이 색을
/// 뒤집어 준다. 그래서 색은 검정 하나로 고정하고 알파만 신경 쓴다.
public enum MenuBarIcon {
    private static let size = NSSize(width: 18, height: 16)

    public static func image() -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            // 획을 1pt로 두면 경로가 픽셀 경계에서 정확히 0.5pt 안쪽에 놓여
            // 레티나에서도 흐려지지 않는다.
            let lineWidth: CGFloat = 1
            let slots = BrandMark.slots(
                in: rect.insetBy(dx: 1, dy: 0), cornerRatio: 0.0625)

            context.setFillColor(NSColor.black.cgColor)
            context.addPath(BrandMark.path([slots.primary], cornerRadius: slots.cornerRadius))
            context.fillPath()

            context.setStrokeColor(NSColor.black.cgColor)
            context.setLineWidth(lineWidth)
            context.addPath(
                BrandMark.path(
                    slots.secondary, cornerRadius: slots.cornerRadius, inset: lineWidth / 2))
            context.strokePath()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "restage"
        return image
    }
}
