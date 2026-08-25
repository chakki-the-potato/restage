import CoreGraphics

public struct SlotMatch: Sendable, Equatable {
    public let slot: Slot
    public let overlap: Double

    public init(slot: Slot, overlap: Double) {
        self.slot = slot
        self.overlap = overlap
    }

    public var isConfident: Bool { overlap >= SlotClassifier.confidenceThreshold }
}

public enum SlotClassifier {
    public static let confidenceThreshold = 0.9

    public static func classify(frame: CGRect, in display: DisplayInfo) -> SlotMatch? {
        ranked(frame: frame, in: display).first
    }

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
