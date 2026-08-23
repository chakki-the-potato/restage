import CoreGraphics

/// 창 하나를 slot 하나에 대응시킨 결과.
public struct SlotMatch: Sendable, Equatable {
    public let slot: Slot
    /// 창과 slot 영역이 겹치는 정도. 0에서 1 사이이며 1이 완전 일치다.
    public let overlap: Double

    public init(slot: Slot, overlap: Double) {
        self.slot = slot
        self.overlap = overlap
    }

    public var isConfident: Bool { overlap >= SlotClassifier.confidenceThreshold }
}

/// 현재 창 위치를 가장 가까운 slot으로 분류한다.
///
/// 좌표를 저장하지 않는다는 원칙을 지키면서 현재 배치를 config로 옮기기 위해 필요하다.
/// 분류가 애매하면 `isConfident`가 false가 되고, 호출자는 사용자에게 되물어야 한다.
/// 조용히 추측한 값을 저장하면 사용자가 의도하지 않은 config가 만들어진다.
public enum SlotClassifier {
    /// 이 값 아래면 되묻는다. 정확히 절반에 놓인 창은 1.0, 한 변이 5% 어긋나면 약 0.9다.
    public static let confidenceThreshold = 0.9

    public static func classify(frame: CGRect, in display: DisplayInfo) -> SlotMatch? {
        ranked(frame: frame, in: display).first
    }

    /// 겹침이 큰 순서로 정렬한 전체 후보. 되물을 때 대안을 제시하는 데 쓴다.
    public static func ranked(frame: CGRect, in display: DisplayInfo) -> [SlotMatch] {
        guard frame.width > 0, frame.height > 0 else { return [] }
        let order = Dictionary(
            uniqueKeysWithValues: Slot.allCases.enumerated().map { ($0.element, $0.offset) })

        return Slot.allCases
            .map { slot in
                let target = SlotGeometry.frame(
                    for: slot, in: display.visibleFrame, primaryMaxY: display.primaryMaxY)
                return SlotMatch(slot: slot, overlap: overlapRatio(frame, target))
            }
            .sorted { lhs, rhs in
                if lhs.overlap != rhs.overlap { return lhs.overlap > rhs.overlap }
                return order[lhs.slot, default: 0] < order[rhs.slot, default: 0]
            }
    }

    /// 교집합 넓이를 합집합 넓이로 나눈 값.
    ///
    /// 교집합 비율만 쓰면 화면을 가득 채운 창이 모든 slot에서 만점을 받는다. 합집합으로
    /// 나누면 모자란 경우와 넘치는 경우가 함께 벌점을 받아 크기까지 반영된다.
    private static func overlapRatio(_ lhs: CGRect, _ rhs: CGRect) -> Double {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, !intersection.isEmpty else { return 0 }
        let intersectionArea = Double(intersection.width) * Double(intersection.height)
        let unionArea =
            Double(lhs.width) * Double(lhs.height)
            + Double(rhs.width) * Double(rhs.height)
            - intersectionArea
        guard unionArea > 0 else { return 0 }
        return intersectionArea / unionArea
    }
}
