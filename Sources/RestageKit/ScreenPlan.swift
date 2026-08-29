import CoreGraphics

public struct DisplayList: Sendable {
    public let primary: DisplayInfo
    public let externals: [DisplayInfo]

    public init(primary: DisplayInfo, externals: [DisplayInfo]) {
        self.primary = primary
        self.externals = externals
    }

    public func selector(containing frame: CGRect) -> DisplaySelector {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        if primary.axBounds.contains(center) { return .builtin }
        for (offset, display) in externals.enumerated() where display.axBounds.contains(center) {
            return .external(index: offset + 1)
        }
        return .builtin
    }

    public func info(for selector: DisplaySelector) -> DisplayInfo? {
        switch selector {
        case .builtin, .any: return primary
        case .external(let index):
            let position = index - 1
            return externals.indices.contains(position) ? externals[position] : nil
        }
    }
}

extension PlannedItem {
    public var hasTitle: Bool {
        if case .place(let placement) = self { return placement.selector.titleContains != nil }
        return false
    }
}

public struct Placement: Sendable, Equatable {
    public let app: AppID
    public let slot: Slot
    public let target: CGRect
    public let selector: WindowSelector
    public let fullscreen: Bool

    public init(
        app: AppID, slot: Slot, target: CGRect,
        selector: WindowSelector = .mostRecentlyActive,
        fullscreen: Bool = false
    ) {
        self.app = app
        self.slot = slot
        self.target = target
        self.selector = selector
        self.fullscreen = fullscreen
    }
}

public struct WindowSelector: Sendable, Equatable {
    public let titleContains: String?

    public static let mostRecentlyActive = WindowSelector(titleContains: nil)

    public init(titleContains: String?) {
        self.titleContains = titleContains
    }
}

public struct TabPlan: Sendable, Equatable {
    public let app: AppID
    public let window: BrowserWindowMode
    public let slot: Slot?
    public let target: CGRect?
    public let tabs: [String]

    public init(
        app: AppID, window: BrowserWindowMode, slot: Slot?, target: CGRect?, tabs: [String]
    ) {
        self.app = app
        self.window = window
        self.slot = slot
        self.target = target
        self.tabs = tabs
    }
}

public enum PlannedItem: Sendable, Equatable {
    case place(Placement)
    case tabs(TabPlan)

    public var app: AppID {
        switch self {
        case .place(let placement): return placement.app
        case .tabs(let plan): return plan.app
        }
    }
}

public struct ScreenPlan: Sendable {
    public let id: String
    public let display: DisplayInfo
    public let mode: ScreenMode
    public let anchor: AppID?
    public let items: [PlannedItem]
}

public struct SkippedScreen: Sendable, Equatable {
    public let id: String
    public let reason: String
}

public struct ResolvedWorkspace: Sendable {
    public let workspace: String
    public let screens: [ScreenPlan]
    public let skipped: [SkippedScreen]
}
