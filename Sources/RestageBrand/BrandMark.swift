import CoreGraphics

public enum BrandMark {
    public struct Slots {
        public let primary: CGRect
        public let secondary: [CGRect]
        public let cornerRadius: CGFloat
    }

    private static let columnRatio: CGFloat = 7.0 / 16.0
    private static let gapRatio: CGFloat = 2.0 / 16.0

    public static func slots(in rect: CGRect, cornerRatio: CGFloat) -> Slots {
        let column = rect.width * columnRatio
        let gap = rect.width * gapRatio
        let row = (rect.height - gap) / 2

        return Slots(
            primary: CGRect(
                x: rect.minX, y: rect.minY, width: column, height: rect.height),
            secondary: [
                CGRect(x: rect.maxX - column, y: rect.maxY - row, width: column, height: row),
                CGRect(x: rect.maxX - column, y: rect.minY, width: column, height: row),
            ],
            cornerRadius: rect.width * cornerRatio)
    }

    public static func path(
        _ rects: [CGRect], cornerRadius: CGFloat, inset: CGFloat = 0
    ) -> CGPath {
        let path = CGMutablePath()
        let radius = max(cornerRadius - inset, 0)
        for rect in rects {
            path.addRoundedRect(
                in: rect.insetBy(dx: inset, dy: inset),
                cornerWidth: radius, cornerHeight: radius)
        }
        return path
    }
}
