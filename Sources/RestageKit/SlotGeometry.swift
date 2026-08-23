import CoreGraphics

public enum SlotGeometry {
    private static let centeredRatio: CGFloat = 2.0 / 3.0

    /// slot을 AX 좌표계(top-left 원점) 사각형으로 변환한다.
    /// - Parameters:
    ///   - visibleFrame: `NSScreen.visibleFrame`. Cocoa 좌표계(bottom-left 원점).
    ///   - primaryMaxY: `NSScreen.screens[0].frame.maxY`. 좌표계 변환 기준선.
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

    /// Cocoa 좌표계(bottom-left 원점, y 위로 증가)를 AX 좌표계(top-left 원점, y 아래로 증가)로 변환한다.
    /// 이 변환식은 프로젝트 전체에서 이 함수에만 존재해야 한다.
    private static func toAX(_ rect: CGRect, primaryMaxY: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryMaxY - rect.maxY, width: rect.width, height: rect.height)
    }

    /// 가용 영역을 정수 좌표로 정규화한다. 경계를 항상 안쪽으로 당겨
    /// 정규화 결과가 원본을 벗어나지 않게 한다. 정수 입력에는 항등이다.
    private static func inscribedIntegral(_ rect: CGRect) -> CGRect {
        let minX = rect.minX.rounded(.up)
        let minY = rect.minY.rounded(.up)
        let maxX = rect.maxX.rounded(.down)
        let maxY = rect.maxY.rounded(.down)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
