import AppKit
import RestageKit

@MainActor
public enum DisplayProvider {
    public static func primary() -> DisplayInfo? {
        guard let primary = NSScreen.screens.first else { return nil }
        return DisplayInfo(visibleFrame: primary.visibleFrame, primaryMaxY: primary.frame.maxY)
    }
}
