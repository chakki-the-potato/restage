import Testing
@testable import RestageKit

private let draft = WorkspaceDraft(
    name: "dev",
    screens: [
        ScreenDraft(
            id: "main", display: .builtin,
            items: [
                .app("Safari", slot: .leftHalf),
                .app("Notion", slot: .rightHalf),
            ]),
        ScreenDraft(
            id: "external-1", display: .external(index: 1),
            items: [
                .app("iTerm", slot: .full),
                .browser("Google Chrome", slot: .q1, tabs: ["https://example.com"]),
            ]),
    ])

@Test func entriesRunAcrossScreens() {
    let entries = DraftSelection.entries(in: draft)
    #expect(entries.map(\.index) == [0, 1, 2, 3])
    #expect(entries.map(\.screenID) == ["main", "main", "external-1", "external-1"])
    #expect(entries.map(\.display) == [.builtin, .builtin, .external(index: 1), .external(index: 1)])
    #expect(entries.map(\.startsScreen) == [true, false, true, false])
    #expect(entries.map(\.item.app) == ["Safari", "Notion", "iTerm", "Google Chrome"])
}

@Test func excludingNothingKeepsEverything() {
    #expect(DraftSelection.apply(excluding: [], to: draft) == draft)
}

@Test func excludesAcrossScreenBoundary() {
    let result = DraftSelection.apply(excluding: [2], to: draft)
    #expect(result.itemCount == 3)
    #expect(result.screens[1].items.map(\.app) == ["Google Chrome"])
    #expect(result.screens[0].items.map(\.app) == ["Safari", "Notion"])
}

@Test func dropsScreenWhenAllItemsExcluded() {
    let result = DraftSelection.apply(excluding: [0, 1], to: draft)
    #expect(result.screens.count == 1)
    #expect(result.screens[0].id == "external-1")
}

@Test func excludingEverythingLeavesNoScreens() {
    let result = DraftSelection.apply(excluding: [0, 1, 2, 3], to: draft)
    #expect(result.screens.isEmpty)
    #expect(result.itemCount == 0)
}

@Test func keepsNameAndHotkey() {
    var withHotkey = draft
    withHotkey.hotkey = "ctrl+alt+cmd+1"
    let result = DraftSelection.apply(excluding: [1], to: withHotkey)
    #expect(result.name == "dev")
    #expect(result.hotkey == "ctrl+alt+cmd+1")
}

@Test func ignoresOutOfRangeIndexes() {
    #expect(DraftSelection.apply(excluding: [99, -1], to: draft) == draft)
}

@Test func writtenSelectionParsesBack() throws {
    let result = DraftSelection.apply(excluding: [1, 2], to: draft)
    let config = try WorkspaceConfig.decode(yaml: ConfigWriter.yaml(for: result))
    #expect(config.screens.count == 2)
    #expect(config.screens[0].items.count == 1)
    #expect(config.screens[1].items.count == 1)
}

@Test func slotOverrideReplacesSavedSlot() {
    let result = DraftSelection.apply(excluding: [], slots: [0: .q4], to: draft)
    #expect(result.screens[0].items[0].slot == .q4)
    #expect(result.screens[0].items[1].slot == .rightHalf)
}

@Test func slotOverrideClearsUncertainty() {
    var uncertain = draft
    uncertain.screens[0].items[0].overlap = 0.4
    #expect(!uncertain.screens[0].items[0].isConfident)

    let result = DraftSelection.apply(excluding: [], slots: [0: .full], to: uncertain)
    #expect(result.screens[0].items[0].isConfident)
}

@Test func slotOverrideAppliesAcrossScreens() {
    let result = DraftSelection.apply(excluding: [], slots: [3: .bottomHalf], to: draft)
    #expect(result.screens[1].items[1].slot == .bottomHalf)
}

@Test func slotOverrideOnExcludedItemIsIgnored() {
    let result = DraftSelection.apply(excluding: [0], slots: [0: .q4], to: draft)
    #expect(result.screens[0].items.map(\.app) == ["Notion"])
}

@Test func slotOverrideSurvivesRoundTrip() throws {
    let result = DraftSelection.apply(excluding: [], slots: [2: .centered], to: draft)
    let config = try WorkspaceConfig.decode(yaml: ConfigWriter.yaml(for: result))
    guard case .app(let item) = config.screens[1].items[0] else {
        Issue.record("app 항목이 아닙니다")
        return
    }
    #expect(item.slot == .centered)
}

@Test func fullscreenOverrideIsApplied() {
    let result = DraftSelection.apply(excluding: [], fullscreen: [0: true], to: draft)
    #expect(result.screens[0].items[0].fullscreen)
    #expect(!result.screens[0].items[1].fullscreen)
}

@Test func fullscreenSurvivesRoundTrip() throws {
    let result = DraftSelection.apply(excluding: [], fullscreen: [0: true], to: draft)
    let config = try WorkspaceConfig.decode(yaml: ConfigWriter.yaml(for: result))
    guard case .app(let item) = config.screens[0].items[0] else {
        Issue.record("app 항목이 아닙니다")
        return
    }
    #expect(item.fullscreen)
}

@Test func fullscreenCanBeTurnedOff() {
    var withFullScreen = draft
    withFullScreen.screens[0].items[0].fullscreen = true
    let result = DraftSelection.apply(excluding: [], fullscreen: [0: false], to: withFullScreen)
    #expect(!result.screens[0].items[0].fullscreen)
}

@Test func addedItemsGoToFirstScreen() {
    let result = DraftSelection.apply(
        excluding: [], added: [.app("Figma", slot: .q1)], to: draft)
    #expect(result.screens[0].items.map(\.app) == ["Safari", "Notion", "Figma"])
    #expect(result.itemCount == 5)
}

@Test func addedItemsCreateScreenWhenAllExcluded() {
    let result = DraftSelection.apply(
        excluding: [0, 1, 2, 3], added: [.app("Figma", slot: .full)], to: draft)
    #expect(result.screens.count == 1)
    #expect(result.screens[0].id == "main")
    #expect(result.screens[0].items.map(\.app) == ["Figma"])
}

@Test func addedFullscreenItemParsesBack() throws {
    let result = DraftSelection.apply(
        excluding: [], added: [.app("Figma", slot: .full, fullscreen: true)], to: draft)
    let config = try WorkspaceConfig.decode(yaml: ConfigWriter.yaml(for: result))
    guard case .app(let item) = config.screens[0].items.last else {
        Issue.record("app 항목이 아닙니다")
        return
    }
    #expect(item.app == AppID("Figma"))
    #expect(item.fullscreen)
}

@Test func missingFullscreenDefaultsToFalse() throws {
    let config = try WorkspaceConfig.decode(yaml: """
        workspace: old
        screens:
          - id: main
            display: builtin
            items:
              - {type: app, app: Safari, slot: full}
        """)
    guard case .app(let item) = config.screens[0].items[0] else {
        Issue.record("app 항목이 아닙니다")
        return
    }
    #expect(!item.fullscreen)
}
