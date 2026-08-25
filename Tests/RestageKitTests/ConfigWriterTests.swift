import Testing
@testable import RestageKit

private func roundTrip(_ draft: WorkspaceDraft) throws -> WorkspaceConfig {
    try WorkspaceConfig.decode(yaml: ConfigWriter.yaml(for: draft))
}

@Test func writtenConfigParsesBack() throws {
    let draft = WorkspaceDraft(
        name: "dev", hotkey: "ctrl+alt+cmd+1",
        screens: [
            ScreenDraft(
                id: "main", display: .builtin,
                items: [
                    .app("Safari", slot: .leftHalf),
                    .app("Notion", slot: .rightHalf),
                ]),
            ScreenDraft(
                id: "external-1", display: .external(index: 1),
                items: [.app("iTerm", slot: .full)]),
        ])

    let config = try roundTrip(draft)
    #expect(config.workspace == "dev")
    #expect(config.hotkey == "ctrl+alt+cmd+1")
    #expect(config.screens.count == 2)
    #expect(config.screens[0].display == .builtin)
    #expect(config.screens[1].display == .external(index: 1))
    #expect(config.screens[0].items.count == 2)
    #expect(config.screens[0].items[0].appID == AppID("Safari"))
}

@Test func browserItemKeepsTabOrder() throws {
    let tabs = ["https://example.com", "https://example.org", "https://example.net"]
    let draft = WorkspaceDraft(
        name: "web",
        screens: [
            ScreenDraft(
                id: "main", display: .any,
                items: [.browser("Google Chrome", slot: .rightHalf, tabs: tabs)]),
        ])

    let config = try roundTrip(draft)
    guard case .browser(let item) = config.screens[0].items[0] else {
        Issue.record("browser 항목이 아닙니다")
        return
    }
    #expect(item.app == AppID("Google Chrome"))
    #expect(item.slot == .rightHalf)
    #expect(item.tabs == tabs)
}

@Test func browserWithoutSlotStaysWithoutSlot() throws {
    let draft = WorkspaceDraft(
        name: "web",
        screens: [
            ScreenDraft(
                id: "main", display: .any,
                items: [.browser("Safari", slot: nil, tabs: ["https://example.com"])]),
        ])

    let config = try roundTrip(draft)
    guard case .browser(let item) = config.screens[0].items[0] else {
        Issue.record("browser 항목이 아닙니다")
        return
    }
    #expect(item.slot == nil)
}

@Test func titleSelectorSurvivesRoundTrip() throws {
    let draft = WorkspaceDraft(
        name: "dev",
        screens: [
            ScreenDraft(
                id: "main", display: .builtin,
                items: [.app("Safari", slot: .leftHalf, title: "시작 페이지")]),
        ])

    let config = try roundTrip(draft)
    guard case .app(let item) = config.screens[0].items[0] else {
        Issue.record("app 항목이 아닙니다")
        return
    }
    #expect(item.title == "시작 페이지")
}

@Test func specialCharactersInNamesAreQuoted() throws {
    let draft = WorkspaceDraft(
        name: "odd",
        screens: [
            ScreenDraft(
                id: "main", display: .builtin,
                items: [.app("Weird: App, Name", slot: .full, title: "a{b}c")]),
        ])

    let config = try roundTrip(draft)
    guard case .app(let item) = config.screens[0].items[0] else {
        Issue.record("app 항목이 아닙니다")
        return
    }
    #expect(item.app == AppID("Weird: App, Name"))
    #expect(item.title == "a{b}c")
}

@Test func reservedWordsAndNumbersAreQuoted() {
    #expect(ConfigWriter.scalar("no") == "\"no\"")
    #expect(ConfigWriter.scalar("true") == "\"true\"")
    #expect(ConfigWriter.scalar("2048") == "\"2048\"")
    #expect(ConfigWriter.scalar("Safari") == "Safari")
    #expect(ConfigWriter.scalar("Google Chrome") == "Google Chrome")
}

@Test func hotkeyIsOmittedWhenAbsent() {
    let draft = WorkspaceDraft(
        name: "dev",
        screens: [ScreenDraft(id: "main", display: .builtin, items: [.app("Safari", slot: .full)])])
    #expect(!ConfigWriter.yaml(for: draft).contains("hotkey"))
}
