/// 아직 파일로 저장되지 않은 워크스페이스.
///
/// `WorkspaceConfig`가 읽기 전용 스키마인 것과 달리 이쪽은 편집 중인 상태를 담는다.
/// 둘을 한 타입으로 합치지 않는 이유는 읽을 때와 만들 때 필요한 것이 다르기 때문이다.
/// 읽을 때는 검증된 값만 있으면 되지만, 만드는 중에는 확신도처럼 저장되지 않는 정보가 붙는다.
public struct WorkspaceDraft: Sendable, Equatable {
    public var name: String
    public var hotkey: String?
    public var screens: [ScreenDraft]

    public init(name: String, hotkey: String? = nil, screens: [ScreenDraft]) {
        self.name = name
        self.hotkey = hotkey
        self.screens = screens
    }

    public var itemCount: Int { screens.reduce(0) { $0 + $1.items.count } }
}

public struct ScreenDraft: Sendable, Equatable {
    public var id: String
    public var display: DisplaySelector
    public var items: [ItemDraft]

    public init(id: String, display: DisplaySelector, items: [ItemDraft]) {
        self.id = id
        self.display = display
        self.items = items
    }
}

public struct ItemDraft: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case app(title: String?)
        case browser(tabs: [String])
    }

    /// 설치된 앱의 표시 이름. bundle ID가 아니다.
    public var app: String
    public var slot: Slot?
    public var kind: Kind
    /// 현재 창 배치에서 분류한 확신도. 낮으면 사용자에게 되묻는다. 저장되지는 않는다.
    public var overlap: Double?
    /// 담을 당시 현재 데스크탑에 있었는지. 저장되지는 않고 확인 목록에만 쓴다.
    public var wasOnCurrentSpace = true

    public init(
        app: String, slot: Slot?, kind: Kind, overlap: Double? = nil,
        wasOnCurrentSpace: Bool = true
    ) {
        self.app = app
        self.slot = slot
        self.kind = kind
        self.overlap = overlap
        self.wasOnCurrentSpace = wasOnCurrentSpace
    }

    public var isConfident: Bool {
        guard let overlap else { return true }
        return overlap >= SlotClassifier.confidenceThreshold
    }

    public static func app(
        _ name: String, slot: Slot, title: String? = nil, overlap: Double? = nil,
        wasOnCurrentSpace: Bool = true
    ) -> ItemDraft {
        ItemDraft(
            app: name, slot: slot, kind: .app(title: title), overlap: overlap,
            wasOnCurrentSpace: wasOnCurrentSpace)
    }

    public static func browser(
        _ name: String, slot: Slot?, tabs: [String], overlap: Double? = nil,
        wasOnCurrentSpace: Bool = true
    ) -> ItemDraft {
        ItemDraft(
            app: name, slot: slot, kind: .browser(tabs: tabs), overlap: overlap,
            wasOnCurrentSpace: wasOnCurrentSpace)
    }

    /// 목록에서 같은 앱의 창을 구분하는 데 쓰는 꼬리표.
    public var titleHint: String? {
        if case .app(let title) = kind { return title }
        return nil
    }
}
