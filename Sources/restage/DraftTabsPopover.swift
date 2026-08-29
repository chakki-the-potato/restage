import Foundation
import RestageKit
import SwiftUI

struct DraftTabsPopover: View {
    @Binding var urls: [String]

    @FocusState private var focused: Int?

    private static let width: CGFloat = 380
    private static let visibleLines = 6
    private static let lineHeight: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string("draft.tabs_hint"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if urls.count > Self.visibleLines {
                ScrollView { lines }
                    .frame(height: CGFloat(Self.visibleLines) * Self.lineHeight)
            } else {
                lines
            }

            Button {
                urls.append("")
                focused = urls.count - 1
            } label: {
                Label(L10n.string("draft.add_url"), systemImage: "plus")
                    .font(.system(size: 11))
            }
            .buttonStyle(.link)
        }
        .padding(10)
        .frame(width: Self.width)
    }

    private var lines: some View {
        VStack(spacing: 4) {
            ForEach(urls.indices, id: \.self) { index in
                HStack(spacing: 6) {
                    TextField("", text: $urls[index])
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                        .focused($focused, equals: index)

                    if DraftTabs.isMalformed(urls[index]) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                            .help(L10n.string("draft.url_invalid"))
                    }

                    Button {
                        urls.remove(at: index)
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16, height: 16)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(L10n.string("draft.remove_url"))
                }
            }
        }
    }

}

enum DraftTabs {
    static func isMalformed(_ url: String) -> Bool {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        guard URLNormalizer.isSavable(trimmed) else { return true }
        guard let host = URLComponents(string: URLNormalizer.normalize(trimmed))?.host
        else { return true }
        return host.isEmpty
    }

    static func cleaned(_ urls: [String]) -> [String] {
        urls
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { isMalformed($0) ? $0 : URLNormalizer.normalize($0) }
    }
}
