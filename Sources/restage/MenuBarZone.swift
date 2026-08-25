import AppKit

enum MenuBarZone {
    static func contains(_ point: CGPoint) -> Bool {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        guard let screen else { return false }
        return contains(
            point, in: screen.frame, visible: screen.visibleFrame,
            thickness: NSStatusBar.system.thickness)
    }

    static func contains(
        _ point: CGPoint, in frame: CGRect, visible: CGRect, thickness: CGFloat
    ) -> Bool {
        guard frame.minX <= point.x, point.x <= frame.maxX else { return false }
        let band = max(frame.maxY - visible.maxY, thickness)
        return point.y >= frame.maxY - band
    }
}
