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

/// 이번 스코프에서 실행하지 않는 항목.
public struct UnsupportedItem: Sendable, Equatable {
    public let app: AppID
    public let reason: String

    public init(app: AppID, reason: String) {
        self.app = app
        self.reason = reason
    }
}

public struct ScreenPlan: Sendable {
    public let id: String
    public let display: DisplayInfo
    public let mode: ScreenMode
    public let anchor: AppID?
    public let placements: [Placement]
    public let unsupported: [UnsupportedItem]
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
