import CoreGraphics

public struct WorkspaceDraft: Sendable, Equatable {
    public var name: String
    public var hotkey: String?
    public var hideOthers: Bool
    public var screens: [ScreenDraft]

    public init(
        name: String, hotkey: String? = nil, hideOthers: Bool = false, screens: [ScreenDraft]
    ) {
        self.name = name
        self.hotkey = hotkey
        self.hideOthers = hideOthers
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

    public var fullscreen = false

    public var app: String
    public var slot: Slot?
    public var kind: Kind
    public var overlap: Double?
    public var wasOnCurrentSpace = true
    public var sourceFrame: CGRect?

    public init(
        app: String, slot: Slot?, kind: Kind, overlap: Double? = nil,
        wasOnCurrentSpace: Bool = true, fullscreen: Bool = false
    ) {
        self.app = app
        self.slot = slot
        self.kind = kind
        self.overlap = overlap
        self.wasOnCurrentSpace = wasOnCurrentSpace
        self.fullscreen = fullscreen
    }

    public var isConfident: Bool {
        guard let overlap else { return true }
        return overlap >= SlotClassifier.confidenceThreshold
    }

    public static func app(
        _ name: String, slot: Slot, title: String? = nil, overlap: Double? = nil,
        wasOnCurrentSpace: Bool = true, fullscreen: Bool = false
    ) -> ItemDraft {
        ItemDraft(
            app: name, slot: slot, kind: .app(title: title), overlap: overlap,
            wasOnCurrentSpace: wasOnCurrentSpace, fullscreen: fullscreen)
    }

    public static func browser(
        _ name: String, slot: Slot?, tabs: [String], overlap: Double? = nil,
        wasOnCurrentSpace: Bool = true, fullscreen: Bool = false
    ) -> ItemDraft {
        ItemDraft(
            app: name, slot: slot, kind: .browser(tabs: tabs), overlap: overlap,
            wasOnCurrentSpace: wasOnCurrentSpace, fullscreen: fullscreen)
    }

    public var titleHint: String? {
        if case .app(let title) = kind { return title }
        return nil
    }

    public var tabs: [String] {
        if case .browser(let tabs) = kind { return tabs }
        return []
    }

    public var isBrowser: Bool {
        if case .browser = kind { return true }
        return false
    }

    public var hasIdentity: Bool {
        switch kind {
        case .app(let title): return !(title ?? "").isEmpty
        case .browser(let tabs): return !tabs.isEmpty
        }
    }
}
