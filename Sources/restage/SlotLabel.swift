import RestageKit

/// slot을 사람이 읽는 이름으로 바꾼다.
///
/// `Slot` 옆이 아니라 여기 두는 이유는 `Slot`이 config 스키마이고 이 이름은 화면에만
/// 쓰이기 때문이다. 스키마에 표시용 문구가 붙으면 둘이 함께 바뀌어야 하는 것처럼 보인다.
enum SlotLabel {
    static func text(_ slot: Slot) -> String {
        switch slot {
        case .full: return "전체"
        case .leftHalf: return "왼쪽 절반"
        case .rightHalf: return "오른쪽 절반"
        case .topHalf: return "위쪽 절반"
        case .bottomHalf: return "아래쪽 절반"
        case .q1: return "좌상"
        case .q2: return "우상"
        case .q3: return "좌하"
        case .q4: return "우하"
        case .centered: return "가운데"
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
