import AppKit
import SwiftUI

enum PanelChromeMetrics {
    static let arrowSize = CGSize(width: 18, height: 9)
    static let cornerRadius: CGFloat = 12
    static let shadowMargin: CGFloat = 16
}

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
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { true }
}

struct PanelChrome<Content: View>: View {
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
