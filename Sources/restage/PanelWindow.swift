import AppKit
import SwiftUI

/// 패널 겉모습의 치수. 창과 배경 뷰가 함께 쓴다.
enum PanelChromeMetrics {
    /// 화살표 꼭지의 크기.
    static let arrowSize = CGSize(width: 18, height: 9)
    static let cornerRadius: CGFloat = 12
    /// 그림자가 잘리지 않도록 창 안쪽에 두는 여백.
    static let shadowMargin: CGFloat = 16
}

/// 메뉴바 아이콘 아래에 뜨는 독립 창.
///
/// `NSPopover`를 쓰지 않는 이유는 그것이 상태 항목 버튼에 묶이기 때문이다. 메뉴바가
/// 숨거나 나타나면 그 버튼의 창이 바뀌고 팝오버가 딸려 닫힌다. 전체화면 앱 위에서
/// 커서를 화면 위쪽에 올리기만 해도 패널이 사라진다.
///
/// 크기는 `contentViewController`에 맡긴다. `contentView`에 직접 넣고 프레임을 손으로
/// 맞추면 뷰와 창의 크기가 어긋나 아무것도 그려지지 않는 상태가 된다. 실제로 겪었다.
final class PanelWindow: NSPanel {
    init(controller: NSViewController) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)

        contentViewController = controller

        isFloatingPanel = true
        level = .popUpMenu
        // 전체화면 앱 위에도 뜨고 Space를 바꿔도 따라온다. 팝오버와 가장 다른 점이다.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        animationBehavior = .none
    }

    /// 키를 받을 수 있어야 텍스트 입력과 Escape가 동작한다.
    override var canBecomeKey: Bool { true }
}

/// 화살표 달린 둥근 배경. 창이 투명하므로 이 뷰가 패널의 겉모습을 전부 그린다.
struct PanelChrome<Content: View>: View {
    /// 그려진 패널 왼쪽 끝에서 화살표 꼭지까지의 거리.
    let arrowOffset: CGFloat
    let content: Content

    init(arrowOffset: CGFloat, @ViewBuilder content: () -> Content) {
        self.arrowOffset = arrowOffset
        self.content = content()
    }

    var body: some View {
        let shape = PanelShape(arrowOffset: arrowOffset)
        return content
            .padding(.top, PanelChromeMetrics.arrowSize.height)
            .background(shape.fill(Color(nsColor: .windowBackgroundColor)))
            .clipShape(shape)
            .overlay(shape.stroke(Color.primary.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.30), radius: 9, y: 3)
            .padding(PanelChromeMetrics.shadowMargin)
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
