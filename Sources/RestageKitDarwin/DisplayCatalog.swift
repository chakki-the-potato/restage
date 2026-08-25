import AppKit
import RestageKit

@MainActor
public enum DisplayCatalog {
    public static func current() -> DisplayList? {
        AppKitBootstrap.ensureGUIApplication()
        let screens = NSScreen.screens
        guard let primaryScreen = screens.first else { return nil }
        let primaryMaxY = primaryScreen.frame.maxY

        let primary = DisplayInfo(
            visibleFrame: primaryScreen.visibleFrame, primaryMaxY: primaryMaxY)

        let externals = screens.dropFirst()
            .sorted { lhs, rhs in
                if lhs.frame.minX != rhs.frame.minX { return lhs.frame.minX < rhs.frame.minX }
                return lhs.frame.minY < rhs.frame.minY
            }
            .map { DisplayInfo(visibleFrame: $0.visibleFrame, primaryMaxY: primaryMaxY) }

        return DisplayList(primary: primary, externals: externals)
    }
}
