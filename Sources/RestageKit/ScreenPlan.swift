import CoreGraphics

/// 사용 가능한 디스플레이 목록. externals는 프레임 원점 기준으로 정렬되어 있어야 한다.
public struct DisplayList: Sendable {
    public let primary: DisplayInfo
    public let externals: [DisplayInfo]

    public init(primary: DisplayInfo, externals: [DisplayInfo]) {
        self.primary = primary
        self.externals = externals
    }

    /// 창 중심이 놓인 디스플레이를 가리키는 선택자. AX 좌표계 사각형을 받는다.
    /// 어느 화면에도 속하지 않으면 주 디스플레이로 본다.
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

/// 한 항목의 배치 목표. target은 AX 좌표계다.
public struct Placement: Sendable, Equatable {
    public let app: AppID
    public let slot: Slot
    public let target: CGRect
    public let selector: WindowSelector

    public init(
        app: AppID, slot: Slot, target: CGRect,
        selector: WindowSelector = .mostRecentlyActive
    ) {
        self.app = app
        self.slot = slot
        self.target = target
        self.selector = selector
    }
}

/// 앱에 창이 여러 개일 때 어느 것을 고를지 정한다.
///
/// 기본값은 가장 최근 활성 창이다. 실사용에서 이 규칙만으로는 어느 창이 옮겨질지
/// 예측하기 어렵다는 점이 드러나 제목 지정을 추가했다.
public struct WindowSelector: Sendable, Equatable {
    /// nil이면 가장 최근 활성 창을 고른다.
    public let titleContains: String?

    public static let mostRecentlyActive = WindowSelector(titleContains: nil)

    public init(titleContains: String?) {
        self.titleContains = titleContains
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
