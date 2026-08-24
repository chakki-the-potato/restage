import RestageKit
import SwiftUI

/// 배치 모양을 작은 도형으로 그린다.
///
/// 글자만으로는 '좌우 분할'과 '상하 분할'을 한눈에 가르기 어렵다. 부제 앞에 실제 모양을
/// 두면 읽지 않고도 구분된다.
struct LayoutGlyph: View {
    let shape: LayoutShape

    private static let size = CGSize(width: 16, height: 12)
    private static let inset: CGFloat = 2
    private static let gap: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let frame = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
            context.stroke(
                Path(roundedRect: frame, cornerRadius: 2),
                with: .color(.secondary.opacity(0.55)), lineWidth: 1)

            let area = frame.insetBy(dx: Self.inset, dy: Self.inset)
            for (index, cell) in cells.enumerated() {
                context.fill(
                    Path(roundedRect: place(cell, in: area), cornerRadius: 1),
                    with: .color(.secondary.opacity(index == 0 ? 0.85 : 0.45)))
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .accessibilityHidden(true)
    }

    /// 0~1 좌표의 칸들. 첫 칸을 진하게 칠해 어느 쪽이 주가 되는지 보여준다.
    private var cells: [CGRect] {
        switch shape {
        case .fullScreen:
            return [CGRect(x: 0, y: 0, width: 1, height: 1)]
        case .single(let slot):
            return [Self.unit(slot)]
        case .leftRight:
            return [Self.unit(.leftHalf), Self.unit(.rightHalf)]
        case .topBottom:
            return [Self.unit(.topHalf), Self.unit(.bottomHalf)]
        case .quarters:
            return [Self.unit(.q1), Self.unit(.q2), Self.unit(.q3), Self.unit(.q4)]
        case .panes(let count):
            return panes(count)
        case .mixed:
            return []
        }
    }

    /// 이름 붙은 조합이 아닌 배치. 왼쪽을 주 칸으로 두고 나머지를 오른쪽에 쌓는다.
    /// 실제 자리를 그대로 옮기지 않는 이유는 16pt 안에서 구분이 되지 않기 때문이다.
    private func panes(_ count: Int) -> [CGRect] {
        let stacked = max(1, count - 1)
        let height = 1.0 / Double(stacked)
        return [Self.unit(.leftHalf)] + (0..<stacked).map { index in
            CGRect(x: 0.5, y: Double(index) * height, width: 0.5, height: height)
        }
    }

    private func place(_ cell: CGRect, in area: CGRect) -> CGRect {
        let half = Self.gap / 2
        return CGRect(
            x: area.minX + cell.minX * area.width,
            y: area.minY + cell.minY * area.height,
            width: cell.width * area.width,
            height: cell.height * area.height
        ).insetBy(dx: cell.width < 1 ? half : 0, dy: cell.height < 1 ? half : 0)
    }

    private static func unit(_ slot: Slot) -> CGRect {
        switch slot {
        case .full: return CGRect(x: 0, y: 0, width: 1, height: 1)
        case .leftHalf: return CGRect(x: 0, y: 0, width: 0.5, height: 1)
        case .rightHalf: return CGRect(x: 0.5, y: 0, width: 0.5, height: 1)
        case .topHalf: return CGRect(x: 0, y: 0, width: 1, height: 0.5)
        case .bottomHalf: return CGRect(x: 0, y: 0.5, width: 1, height: 0.5)
        case .q1: return CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        case .q2: return CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5)
        case .q3: return CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5)
        case .q4: return CGRect(x: 0.5, y: 0.5, width: 0.5, height: 0.5)
        case .centered: return CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        }
    }
}
