import RestageKit
import SwiftUI

/// 워크스페이스에 든 앱을 겹쳐 그린다.
///
/// 개수를 세 개로 끊는 이유는 폭을 고정하기 위해서다. 앱 수에 따라 폭이 변하면 옆의 이름이
/// 카드마다 다른 자리에서 시작해 목록이 흔들린다.
struct AppIconStack: View {
    let apps: [AppID]
    var isDimmed = false

    private static let limit = 3
    private static let side: CGFloat = 21
    private static let overlap: CGFloat = -7
    private static let ring: CGFloat = 3

    private var shown: [AppID] { Array(apps.prefix(Self.limit)) }
    private var hidden: Int { max(0, apps.count - Self.limit) }

    var body: some View {
        HStack(spacing: Self.overlap) {
            ForEach(shown, id: \.rawValue) { app in
                mark(WorkspaceIcons.mark(for: app))
                    .frame(width: Self.side, height: Self.side)
                    .overlay(shape.strokeBorder(PanelPalette.iconRing, lineWidth: Self.ring))
            }
            if hidden > 0 {
                Text("+\(hidden)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .frame(height: Self.side)
                    .background(shape.fill(Color.primary.opacity(0.07)))
                    .overlay(shape.strokeBorder(PanelPalette.iconRing, lineWidth: Self.ring))
            }
        }
        .opacity(isDimmed ? 0.4 : 1)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
    }

    @ViewBuilder
    private func mark(_ mark: WorkspaceIcons.Mark) -> some View {
        switch mark {
        case .icon(let image):
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
        case .monogram(let letter):
            letterMark(letter)
                .foregroundStyle(.secondary)
                .background(shape.fill(Color.primary.opacity(0.10)))
        case .missing(let letter):
            letterMark(letter)
                .foregroundStyle(.tertiary)
                .background(shape.strokeBorder(Color.primary.opacity(0.25), style: dashed))
        }
    }

    private var dashed: StrokeStyle {
        StrokeStyle(lineWidth: 1, dash: [3, 2])
    }

    private func letterMark(_ letter: String) -> some View {
        Text(letter)
            .font(.system(size: 11, weight: .bold))
            .frame(width: Self.side, height: Self.side)
    }
}
