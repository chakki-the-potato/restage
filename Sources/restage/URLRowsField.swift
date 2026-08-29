import RestageKit
import SwiftUI

struct URLRowsField: View {
    @Binding var rows: [String]
    let leadingInset: CGFloat
    let trailingWidth: CGFloat
    let spacing: CGFloat

    @FocusState private var focused: Int?

    private static let rowSpacing: CGFloat = 4
    private static let visibleRows = 6
    private static let scrolledRows = 4

    @ViewBuilder
    var body: some View {
        if rows.count > Self.visibleRows {
            ScrollView { list }.frame(height: Self.height(of: Self.scrolledRows))
        } else {
            list
        }
    }

    private static func height(of count: Int) -> CGFloat {
        let row = FieldBox.contentHeight + 6
        return CGFloat(count) * row + CGFloat(count - 1) * rowSpacing
    }

    private var list: some View {
        VStack(spacing: Self.rowSpacing) {
            ForEach(rows.indices, id: \.self) { index in row(index) }
        }
    }

    private func row(_ index: Int) -> some View {
        HStack(spacing: spacing) {
            Color.clear.frame(width: leadingInset, height: 0)

            HStack(spacing: 5) {
                TextField(placeholder(index), text: $rows[index])
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(height: FieldBox.contentHeight)
                    .focused($focused, equals: index)
                    .onSubmit { insert(after: index) }
                if DraftTabs.isMalformed(rows[index]) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                        .help(L10n.string("draft.url_invalid"))
                }
            }
            .padding(.horizontal, 5)
            .fieldBox()

            button(index).frame(width: trailingWidth)
        }
    }

    @ViewBuilder
    private func button(_ index: Int) -> some View {
        if index == rows.indices.last {
            FieldIconButton(symbol: "plus", help: L10n.string("draft.add_url")) {
                insert(after: index)
            }
        } else {
            FieldIconButton(symbol: "minus", help: L10n.string("draft.remove_url")) {
                remove(index)
            }
        }
    }

    private func placeholder(_ index: Int) -> String {
        index == 0 ? L10n.string("draft.url_placeholder") : ""
    }

    private func insert(after index: Int) {
        rows.insert("", at: index + 1)
        focused = index + 1
    }

    private func remove(_ index: Int) {
        guard rows.indices.contains(index) else { return }
        rows.remove(at: index)
        if rows.isEmpty { rows = [""] }
        focused = min(index, rows.count - 1)
    }
}
