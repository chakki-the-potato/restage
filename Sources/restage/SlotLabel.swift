import RestageKit

enum SlotLabel {
    static func text(_ slot: Slot) -> String {
        L10n.string(key(slot))
    }

    private static func key(_ slot: Slot) -> String {
        switch slot {
        case .full: return "slot.full"
        case .leftHalf: return "slot.left_half"
        case .rightHalf: return "slot.right_half"
        case .topHalf: return "slot.top_half"
        case .bottomHalf: return "slot.bottom_half"
        case .q1: return "slot.q1"
        case .q2: return "slot.q2"
        case .q3: return "slot.q3"
        case .q4: return "slot.q4"
        case .centered: return "slot.centered"
        }
    }

    static func picker() -> String {
        Slot.allCases.enumerated()
            .map { "  \(String(format: "%2d", $0.offset + 1)) \(text($0.element))" }
            .joined(separator: "\n")
    }

    static func slot(atChoice choice: Int) -> Slot? {
        let index = choice - 1
        return Slot.allCases.indices.contains(index) ? Slot.allCases[index] : nil
    }
}
