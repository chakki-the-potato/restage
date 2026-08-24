import SwiftUI

/// 패널 안에 떠 있는 메뉴.
///
/// `Menu`(macOS 메뉴)를 쓰지 않는 이유는 그것이 열려 있는 동안 클릭을 독차지하기 때문이다.
/// 화면 다른 곳을 눌러도 메뉴만 닫히고 패널이 남아 두 번 눌러야 했다. 메뉴 추적 중에는
/// 이벤트가 앱까지 오지 않으므로 코드로 그 클릭을 잡을 수 없다.
///
/// 그래서 모양만 메뉴처럼 그리고 실제로는 패널 안의 뷰로 둔다. 클릭이 패널까지 닿아
/// 팝오버가 한 번에 닫힌다.
struct FloatingMenu<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(.vertical, 5)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
    }
}

/// 떠 있는 메뉴의 항목 하나.
struct FloatingMenuItem: View {
    let title: String
    let symbol: String
    var tint: Color?
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 11))
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isHovering ? Color.white : (tint ?? .primary))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovering ? (tint ?? Color.accentColor) : .clear)
                    .padding(.horizontal, 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }
}

extension FloatingMenu {
    /// 항목 사이 구분선. 메뉴 안쪽 여백에 맞춰 들여쓴다.
    static var separator: some View {
        Divider().padding(.horizontal, 10).padding(.vertical, 4)
    }
}

/// 떠 있는 메뉴를 어디에 그릴지 알려주는 통로.
///
/// 카드가 자기 버튼의 위치를 패널 좌표계로 올려보내면, 패널이 그 자리에 메뉴를 띄운다.
/// 카드 안에 그리면 다음 카드에 가려지고 카드 높이도 늘어난다.
struct MenuAnchorKey: PreferenceKey {
    static var defaultValue: [String: CGRect] { [:] }

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    /// 이 뷰의 위치를 패널 좌표계로 올려보낸다.
    func menuAnchor(_ key: String, in space: String) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: MenuAnchorKey.self, value: [key: proxy.frame(in: .named(space))])
            })
    }
}
