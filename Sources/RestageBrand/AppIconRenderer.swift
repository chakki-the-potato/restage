import CoreGraphics

/// Finder와 시스템 설정 목록에 보이는 앱 아이콘을 그린다.
///
/// macOS 앱 아이콘은 캔버스를 꽉 채우지 않는다. 여백을 두고 둥근 사각형 판을 얹은 뒤
/// 그 위에 마크를 올려야 다른 앱들과 크기가 맞아 보인다.
public enum AppIconRenderer {
    /// 이 크기 이하에서는 선으로 그린 슬롯의 안쪽 구멍이 1픽셀도 안 남아 뭉갠다.
    /// 그래서 셋 다 채우고 마크를 키운 단순한 그림으로 바꾼다.
    private static let simplifiedThreshold = 40

    private static let plateInsetRatio: CGFloat = 100.0 / 1024.0
    private static let plateCornerRatio: CGFloat = 0.2247

    public struct Palette: Sendable {
        public let top: CGColor
        public let bottom: CGColor
        public let mark: CGColor

        public init(top: CGColor, bottom: CGColor, mark: CGColor) {
            self.top = top
            self.bottom = bottom
            self.mark = mark
        }
    }

    public static func render(pixels: Int, palette: Palette = .standard) -> CGImage? {
        let side = CGFloat(pixels)
        guard let context = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return nil }

        context.setShouldAntialias(true)
        context.interpolationQuality = .high

        let plate = drawPlate(in: context, side: side, palette: palette)
        drawMark(
            in: context, plate: plate, color: palette.mark,
            simplified: pixels <= simplifiedThreshold)

        return context.makeImage()
    }

    private static func drawPlate(
        in context: CGContext, side: CGFloat, palette: Palette
    ) -> CGRect {
        let inset = side * plateInsetRatio
        let plate = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
        let radius = plate.width * plateCornerRatio
        let path = CGPath(
            roundedRect: plate, cornerWidth: radius, cornerHeight: radius, transform: nil)

        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -side * 0.012), blur: side * 0.024,
            color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.28))
        context.setFillColor(palette.bottom)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(path)
        context.clip()
        if let gradient = CGGradient(
            colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [palette.top, palette.bottom] as CFArray, locations: [0, 1]
        ) {
            context.drawLinearGradient(
                gradient, start: CGPoint(x: plate.midX, y: plate.maxY),
                end: CGPoint(x: plate.midX, y: plate.minY), options: [])
        }
        context.restoreGState()

        return plate
    }

    private static func drawMark(
        in context: CGContext, plate: CGRect, color: CGColor, simplified: Bool
    ) {
        let insetRatio: CGFloat = simplified ? 0.19 : 0.24
        let mark = plate.insetBy(dx: plate.width * insetRatio, dy: plate.height * insetRatio)
        let slots = BrandMark.slots(in: mark, cornerRatio: simplified ? 0.05 : 0.085)

        context.setFillColor(color)
        if simplified {
            context.addPath(
                BrandMark.path([slots.primary] + slots.secondary, cornerRadius: slots.cornerRadius))
            context.fillPath()
            return
        }

        context.addPath(BrandMark.path([slots.primary], cornerRadius: slots.cornerRadius))
        context.fillPath()

        let lineWidth = mark.width * 0.065
        context.setStrokeColor(color)
        context.setLineWidth(lineWidth)
        context.addPath(
            BrandMark.path(
                slots.secondary, cornerRadius: slots.cornerRadius, inset: lineWidth / 2))
        context.strokePath()
    }
}

extension AppIconRenderer.Palette {
    private static func color(_ r: Double, _ g: Double, _ b: Double) -> CGColor {
        CGColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    /// 흰 판에 먹색 마크. 흰 배경에서는 판 자체가 묻히지만 아래로 갈수록 어두워지는
    /// 그라디언트와 그림자가 경계를 만든다. 테두리를 덧대지 않는 이유다.
    public static let standard = Self(
        top: color(0.99, 0.99, 1.00), bottom: color(0.87, 0.88, 0.91),
        mark: color(0.13, 0.14, 0.17))
}
