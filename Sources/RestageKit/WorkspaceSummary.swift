/// 주 화면의 창 배치 모양.
///
/// 목록에서 워크스페이스를 알아보는 단서는 이름보다 배치다. 어느 자리에 몇 개를 놓는지는
/// config에 이미 적혀 있으므로 파일을 열지 않고도 판정할 수 있다.
public enum LayoutShape: Sendable, Equatable {
    case fullScreen
    /// 창 하나만 특정 자리에 놓는 배치.
    case single(Slot)
    case leftRight
    case topBottom
    case quarters
    /// 서로 다른 자리 N개. 위의 이름 붙은 조합에 해당하지 않을 때 쓴다.
    case panes(Int)
    /// 자리를 알 수 없는 항목뿐이라 모양을 말할 수 없는 경우.
    case mixed
}

/// 목록 한 줄을 그리는 데 필요한 것만 config에서 뽑아 둔 값.
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

    /// 나온 순서를 지키면서 같은 앱은 한 번만 남긴다. 아이콘을 겹쳐 그릴 때 같은 아이콘이
    /// 두 번 나오면 항목 수를 잘못 읽게 된다.
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
    /// 자리를 지정하지 않는 항목이 있다. 브라우저는 창 크기를 그대로 두는 선택지가 있다.
    public var slot: Slot? {
        switch self {
        case .app(let item): return item.fullscreen ? nil : item.slot
        case .browser(let item): return item.slot
        }
    }
}
