import RestageKit
import SwiftUI

struct AppNameField: View {
    @Binding var text: String
    let placeholder: String
    let isDropTarget: Bool
    let onChooseFile: () -> Void

    @State private var isHovering = false

    private static let buttonWidth: CGFloat = 24
    private static let reaction: Animation = .easeOut(duration: 0.12)

    var body: some View {
        HStack(spacing: 0) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(height: FieldBox.contentHeight)
            folderButton
        }
        .padding(.leading, 5)
        .fieldBox(isHighlighted: isDropTarget)
        .animation(Self.reaction, value: isDropTarget)
        .animation(Self.reaction, value: isHovering)
    }

    private var folderButton: some View {
        Button(action: onChooseFile) {
            Image(systemName: isDropTarget ? "folder.badge.plus" : "folder")
                .font(.system(size: 11))
                .foregroundStyle(iconColor)
                .frame(width: Self.buttonWidth, height: FieldBox.contentHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(FieldIconButtonStyle(isHovering: isHovering))
        .onHover { isHovering = $0 }
        .help(L10n.string("draft.choose_app_file"))
    }

    private var iconColor: Color {
        if isDropTarget { return .accentColor }
        return isHovering ? .primary : .secondary
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
