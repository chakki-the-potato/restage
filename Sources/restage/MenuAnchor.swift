import SwiftUI

/// 메뉴를 띄울 자리를 알려주는 통로.
///
/// 버튼이 자기 위치를 창 좌표로 올려보내면, 컨트롤러가 창 위치를 더해 화면 좌표로 바꾼다.
struct MenuAnchorKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// 이 뷰의 위치를 창 좌표로 올려보낸다.
    func menuAnchor(_ key: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: MenuAnchorKey.self, value: [key: proxy.frame(in: .global)])
            })
    }
}
