import RestageKit

/// slot을 사람이 읽는 이름으로 바꾼다.
///
/// `Slot` 옆이 아니라 여기 두는 이유는 `Slot`이 config 스키마이고 이 이름은 화면에만
/// 쓰이기 때문이다. 스키마에 표시용 문구가 붙으면 둘이 함께 바뀌어야 하는 것처럼 보인다.
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

    /// 고르라고 보여주는 목록. 번호는 1부터다.
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
