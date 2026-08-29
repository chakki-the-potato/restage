import RestageKit
import SwiftUI

struct AppNameField: View {
    @Binding var text: String
    let placeholder: String
    let isDropTarget: Bool
    let onChooseFile: () -> Void

    private static let reaction: Animation = .easeOut(duration: 0.12)

    var body: some View {
        HStack(spacing: 0) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(height: FieldBox.contentHeight)
            FieldIconButton(
                symbol: isDropTarget ? "folder.badge.plus" : "folder",
                help: L10n.string("draft.choose_app_file"),
                tint: isDropTarget ? .accentColor : nil,
                action: onChooseFile)
        }
        .padding(.leading, 5)
        .fieldBox(isHighlighted: isDropTarget)
        .animation(Self.reaction, value: isDropTarget)
    }
}
