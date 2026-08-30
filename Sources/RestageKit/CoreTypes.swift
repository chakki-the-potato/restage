import CoreGraphics

public struct AppID: Hashable, Sendable, RawRepresentable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct ProcessHandle: Sendable {
    public let pid: Int32
    public let wasLaunched: Bool

    public init(pid: Int32, wasLaunched: Bool) {
        self.pid = pid
        self.wasLaunched = wasLaunched
    }
}

public struct DisplayInfo: Sendable {
    public let visibleFrame: CGRect
    public let primaryMaxY: CGFloat

    public init(visibleFrame: CGRect, primaryMaxY: CGFloat) {
        self.visibleFrame = visibleFrame
        self.primaryMaxY = primaryMaxY
    }

    public var axBounds: CGRect {
        CGRect(
            x: visibleFrame.minX, y: primaryMaxY - visibleFrame.maxY,
            width: visibleFrame.width, height: visibleFrame.height)
    }
}

@MainActor
public protocol WindowHandle {
    var currentFrame: CGRect? { get }
    var isOnActiveSpace: Bool { get }
    var wasOpened: Bool { get }
}
