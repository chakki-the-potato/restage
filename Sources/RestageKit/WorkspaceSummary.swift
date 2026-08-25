public enum LayoutShape: Sendable, Equatable {
    case fullScreen
    case single(Slot)
    case leftRight
    case topBottom
    case quarters
    case panes(Int)
    case mixed
}

public struct WorkspaceSummary: Sendable, Equatable {
    public let apps: [AppID]
    public let shape: LayoutShape
    public let screenCount: Int
    public let itemCount: Int

    public init(apps: [AppID], shape: LayoutShape, screenCount: Int, itemCount: Int) {
        self.apps = apps
        self.shape = shape
        self.screenCount = screenCount
        self.itemCount = itemCount
    }

    public init(config: WorkspaceConfig) {
        apps = Self.apps(in: config)
        shape = config.screens.first.map(Self.shape(of:)) ?? .mixed
        screenCount = config.screens.count
        itemCount = config.screens.reduce(0) { $0 + $1.items.count }
    }

    private static func apps(in config: WorkspaceConfig) -> [AppID] {
        var seen: Set<AppID> = []
        return config.screens.flatMap(\.items).map(\.appID).filter { seen.insert($0).inserted }
    }

    private static func shape(of screen: ScreenConfig) -> LayoutShape {
        if screen.mode == .fullscreen { return .fullScreen }

        let slots = Set(screen.items.compactMap(\.slot))
        switch slots {
        case []: return .mixed
        case [.full]: return .fullScreen
        case [.leftHalf, .rightHalf]: return .leftRight
        case [.topHalf, .bottomHalf]: return .topBottom
        case [.q1, .q2, .q3, .q4]: return .quarters
        default:
            guard let only = slots.first, slots.count == 1 else { return .panes(slots.count) }
            return .single(only)
        }
    }
}

extension ItemConfig {
    public var slot: Slot? {
        switch self {
        case .app(let item): return item.fullscreen ? nil : item.slot
        case .browser(let item): return item.slot
        }
    }
}
