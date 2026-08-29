import SwiftUI

struct FieldBox: ViewModifier {
    let isHighlighted: Bool

    static let cornerRadius: CGFloat = 5
    static let contentHeight: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 3)
            .background(shape)
    }

    private var shape: some View {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            .fill(isHighlighted
                ? Color.accentColor.opacity(0.08)
                : Color(nsColor: .textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .strokeBorder(
                        isHighlighted ? Color.accentColor : Color(nsColor: .separatorColor),
                        lineWidth: isHighlighted ? 1.5 : 1))
    }
}

extension View {
    func fieldBox(isHighlighted: Bool = false) -> some View {
        modifier(FieldBox(isHighlighted: isHighlighted))
    }
}
