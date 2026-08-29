import SwiftUI

struct FieldIconButton: View {
    let symbol: String
    let help: String
    var tint: Color?
    let action: () -> Void

    @State private var isHovering = false

    static let width: CGFloat = 24

    private static let reaction: Animation = .easeOut(duration: 0.12)

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(tint ?? (isHovering ? Color.primary : Color.secondary))
                .frame(width: Self.width, height: FieldBox.contentHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(FieldIconButtonStyle(isHovering: isHovering))
        .onHover { isHovering = $0 }
        .help(help)
        .animation(Self.reaction, value: isHovering)
    }
}

private struct FieldIconButtonStyle: ButtonStyle {
    let isHovering: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.primary.opacity(shade(pressed: configuration.isPressed))))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func shade(pressed: Bool) -> Double {
        if pressed { return 0.12 }
        return isHovering ? 0.08 : 0
    }
}
