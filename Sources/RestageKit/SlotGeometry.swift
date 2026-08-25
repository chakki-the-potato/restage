import CoreGraphics

public enum SlotGeometry {
    private static let centeredRatio: CGFloat = 2.0 / 3.0

    public static func frame(for slot: Slot, in visibleFrame: CGRect, primaryMaxY: CGFloat) -> CGRect {
        toAX(cocoaFrame(for: slot, in: visibleFrame), primaryMaxY: primaryMaxY)
    }

    private static func cocoaFrame(for slot: Slot, in visibleFrame: CGRect) -> CGRect {
        let vf = inscribedIntegral(visibleFrame)
        let leftWidth = (vf.width / 2).rounded(.up)
        let rightWidth = vf.width - leftWidth
        let topHeight = (vf.height / 2).rounded(.up)
        let bottomHeight = vf.height - topHeight
        let topY = vf.maxY - topHeight

        switch slot {
        case .full:
            return vf
        case .leftHalf:
            return CGRect(x: vf.minX, y: vf.minY, width: leftWidth, height: vf.height)
        case .rightHalf:
            return CGRect(x: vf.minX + leftWidth, y: vf.minY, width: rightWidth, height: vf.height)
        case .topHalf:
            return CGRect(x: vf.minX, y: topY, width: vf.width, height: topHeight)
        case .bottomHalf:
            return CGRect(x: vf.minX, y: vf.minY, width: vf.width, height: bottomHeight)
        case .q1:
            return CGRect(x: vf.minX, y: topY, width: leftWidth, height: topHeight)
        case .q2:
            return CGRect(x: vf.minX + leftWidth, y: topY, width: rightWidth, height: topHeight)
        case .q3:
            return CGRect(x: vf.minX, y: vf.minY, width: leftWidth, height: bottomHeight)
        case .q4:
            return CGRect(x: vf.minX + leftWidth, y: vf.minY, width: rightWidth, height: bottomHeight)
        case .centered:
            let width = (vf.width * centeredRatio).rounded()
            let height = (vf.height * centeredRatio).rounded()
            return CGRect(
                x: vf.minX + ((vf.width - width) / 2).rounded(),
                y: vf.minY + ((vf.height - height) / 2).rounded(),
                width: width,
                height: height)
        }
    }

    private static func toAX(_ rect: CGRect, primaryMaxY: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryMaxY - rect.maxY, width: rect.width, height: rect.height)
    }

    private static func inscribedIntegral(_ rect: CGRect) -> CGRect {
        let minX = rect.minX.rounded(.up)
        let minY = rect.minY.rounded(.up)
        let maxX = rect.maxX.rounded(.down)
        let maxY = rect.maxY.rounded(.down)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
