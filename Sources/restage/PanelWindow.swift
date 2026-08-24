import AppKit
import SwiftUI

/// 메뉴바 아이콘 아래에 뜨는 독립 창.
///
/// `NSPopover`를 쓰지 않는 이유는 그것이 상태 항목 버튼에 묶이기 때문이다. 메뉴바가
/// 숨거나 나타나면 그 버튼의 창이 바뀌고 팝오버가 딸려 닫힌다. 전체화면 앱 위에서
/// 커서를 화면 위쪽에 올리기만 해도 패널이 사라진다.
///
/// 독립 창은 그런 결합이 없다. 대신 위치와 닫기를 직접 관리해야 한다.
///
/// 모양 상수는 창과 배경 뷰가 함께 쓰므로 어느 쪽에도 속하지 않는 곳에 둔다.
enum PanelChromeMetrics {
    /// 화살표 꼭지의 크기.
    static let arrowSize = CGSize(width: 18, height: 9)
    static let cornerRadius: CGFloat = 12
}

final class PanelWindow: NSPanel {

    init(content: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)

        isFloatingPanel = true
        level = .popUpMenu
        // 전체화면 앱 위에도 뜨고 Space를 바꿔도 따라온다. 이것이 팝오버와 가장 다른 점이다.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        animationBehavior = .none

        contentView = content
    }

    /// 키를 받을 수 있어야 텍스트 입력과 Escape가 동작한다.
    override var canBecomeKey: Bool { true }
}

/// 화살표 달린 둥근 배경. 창이 투명하므로 이 뷰가 패널의 겉모습을 전부 그린다.
struct PanelChrome<Content: View>: View {
    /// 창 왼쪽 끝에서 화살표 꼭지까지의 거리.
    let arrowOffset: CGFloat
    let content: Content

    init(arrowOffset: CGFloat, @ViewBuilder content: () -> Content) {
        self.arrowOffset = arrowOffset
        self.content = content()
    }

    var body: some View {
        content
            .background(
                PanelShape(arrowOffset: arrowOffset)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.28), radius: 12, y: 3))
            .overlay(
                PanelShape(arrowOffset: arrowOffset)
                    .stroke(Color.primary.opacity(0.10), lineWidth: 1))
            .padding(.top, PanelChromeMetrics.arrowSize.height)
    }
}

/// 위쪽에 화살표가 붙은 둥근 사각형.
private struct PanelShape: Shape {
    let arrowOffset: CGFloat

    func path(in rect: CGRect) -> Path {
        let arrow = PanelChromeMetrics.arrowSize
        let body = CGRect(
            x: rect.minX, y: rect.minY + arrow.height,
            width: rect.width, height: rect.height - arrow.height)
        let tip = min(max(arrowOffset, arrow.width), rect.width - arrow.width)

        var path = Path(
            roundedRect: body, cornerRadius: PanelChromeMetrics.cornerRadius, style: .continuous)
        path.move(to: CGPoint(x: tip - arrow.width / 2, y: body.minY))
        path.addLine(to: CGPoint(x: tip, y: rect.minY))
        path.addLine(to: CGPoint(x: tip + arrow.width / 2, y: body.minY))
        path.closeSubpath()
        return path
    }
}
