import CoreGraphics

/// 사용 가능한 디스플레이 목록. externals는 프레임 원점 기준으로 정렬되어 있어야 한다.
public struct DisplayList: Sendable {
    public let primary: DisplayInfo
    public let externals: [DisplayInfo]

    public init(primary: DisplayInfo, externals: [DisplayInfo]) {
        self.primary = primary
        self.externals = externals
    }
}

/// 한 항목의 배치 목표. target은 AX 좌표계다.
public struct Placement: Sendable, Equatable {
    public let app: AppID
    public let slot: Slot
    public let target: CGRect

    public init(app: AppID, slot: Slot, target: CGRect) {
        self.app = app
        self.slot = slot
        self.target = target
    }
}

/// 브라우저 항목의 해석 결과. tabs는 정규화되어 있다.
public struct TabPlan: Sendable, Equatable {
    public let app: AppID
    public let window: BrowserWindowMode
    public let slot: Slot?
    /// slot이 있을 때만 값이 있다.
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

/// 화면의 항목 하나. config 배열 순서를 그대로 유지한다.
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
