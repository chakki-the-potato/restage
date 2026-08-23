import CoreGraphics

/// restage 마크의 기하 정의.
///
/// 앱 아이콘과 메뉴바 아이콘은 같은 그림을 크기만 달리 쓴다. 좌표 계산이 두 곳으로
/// 갈라지면 한쪽만 고쳐지므로 배치는 여기서만 정하고, 렌더러는 색과 굵기만 정한다.
public enum BrandMark {
    /// 큰 슬롯 하나와 작은 슬롯 둘. 어느 쪽을 채우고 어느 쪽을 선으로 그릴지는
    /// 크기에 따라 달라지므로 렌더러가 정한다.
    public struct Slots {
        public let primary: CGRect
        public let secondary: [CGRect]
        public let cornerRadius: CGFloat
    }

    /// 슬롯 7 + 간격 2 + 슬롯 7 = 16. 메뉴바 아이콘이 16pt라 이 비율이어야
    /// 모든 변이 정수 좌표에 떨어지고 가장자리에 회색이 끼지 않는다.
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

    /// - Parameter inset: 선으로 그릴 때 획이 슬롯 밖으로 삐져나오지 않도록 당길 거리.
    ///   획 굵기의 절반을 넘긴다.
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
