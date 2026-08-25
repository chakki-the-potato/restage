import SwiftUI

struct MenuAnchorKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    func menuAnchor(_ key: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: MenuAnchorKey.self, value: [key: proxy.frame(in: .global)])
            })
    }
}
