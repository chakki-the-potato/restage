import Testing
@testable import RestageKit

private let yaml = """
    workspace: dev
    hotkey: "ctrl+alt+cmd+1"
    screens:
      - id: main
        display: builtin
        items:
          - {type: app, app: Safari, slot: left-half, title: 문서}
          - {type: app, app: Notion, slot: right-half}
      - id: external-1
        display: external-1
        items:
          - type: browser
            app: Google Chrome
            slot: full
            tabs:
              - https://example.com
              - https://example.org
    """

@Test func configBecomesEditableDraft() throws {
    let draft = DraftFromConfig.draft(from: try WorkspaceConfig.decode(yaml: yaml))

    #expect(draft.name == "dev")
    #expect(draft.hotkey == "ctrl+alt+cmd+1")
    #expect(draft.screens.map(\.id) == ["main", "external-1"])
    #expect(draft.screens[0].display == .builtin)
    #expect(draft.screens[1].display == .external(index: 1))
    #expect(draft.itemCount == 3)
}

@Test func appItemKeepsSlotAndTitle() throws {
    let draft = DraftFromConfig.draft(from: try WorkspaceConfig.decode(yaml: yaml))
    let item = draft.screens[0].items[0]
    #expect(item.app == "Safari")
    #expect(item.slot == .leftHalf)
    #expect(item.titleHint == "문서")
}

@Test func browserItemKeepsTabs() throws {
    let draft = DraftFromConfig.draft(from: try WorkspaceConfig.decode(yaml: yaml))
    guard case .browser(let tabs) = draft.screens[1].items[0].kind else {
        Issue.record("browser 항목이 아닙니다")
        return
    }
    #expect(tabs == ["https://example.com", "https://example.org"])
}

@Test func savedItemsAreConfident() throws {
    let draft = DraftFromConfig.draft(from: try WorkspaceConfig.decode(yaml: yaml))
    for screen in draft.screens {
        for item in screen.items {
            #expect(item.isConfident)
            #expect(item.wasOnCurrentSpace)
        }
    }
}

@Test func draftSurvivesRoundTripThroughWriter() throws {
    let original = try WorkspaceConfig.decode(yaml: yaml)
    let draft = DraftFromConfig.draft(from: original)
    let reparsed = try WorkspaceConfig.decode(yaml: ConfigWriter.yaml(for: draft))

    #expect(reparsed.workspace == original.workspace)
    #expect(reparsed.hotkey == original.hotkey)
    #expect(reparsed.screens.count == original.screens.count)
    #expect(reparsed.screens[0].items.count == 2)

    guard case .app(let item) = reparsed.screens[0].items[0] else {
        Issue.record("app 항목이 아닙니다")
        return
    }
    #expect(item.app == AppID("Safari"))
    #expect(item.slot == .leftHalf)
    #expect(item.title == "문서")
}

@Test func editedBrowserWithoutSlotStaysWithoutSlot() throws {
    let config = try WorkspaceConfig.decode(yaml: """
        workspace: web
        screens:
          - id: main
            display: any
            items:
              - type: browser
                app: Safari
                tabs: [https://example.com]
        """)
    let draft = DraftFromConfig.draft(from: config)
    #expect(draft.screens[0].items[0].slot == nil)
}
