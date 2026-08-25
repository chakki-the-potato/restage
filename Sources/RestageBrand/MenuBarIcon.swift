import AppKit

public enum MenuBarIcon {
    private static let size = NSSize(width: 18, height: 16)

    public static func image() -> NSImage {
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
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
