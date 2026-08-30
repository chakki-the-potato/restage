import Testing
@testable import RestageKit

private let sample = """
workspace: dev
hotkey: "ctrl+alt+cmd+1"
screens:
  - id: code
    display: builtin
    mode: fullscreen
    anchor: cursor
    items:
      - {type: app, app: cursor, slot: left-half}
      - {type: app, app: iterm}
  - id: research
    items:
      - type: browser
        app: chrome
        tabs:
          - https://example.com/a
          - https://example.com/b
"""

@Test func decodesFullSchema() throws {
    let config = try WorkspaceConfig.decode(yaml: sample)
    #expect(config.workspace == "dev")
    #expect(config.hotkey == "ctrl+alt+cmd+1")
    #expect(config.screens.count == 2)
}

@Test func decodesAppItemsWithSlot() throws {
    let config = try WorkspaceConfig.decode(yaml: sample)
    let items = config.screens[0].items
    #expect(items.count == 2)
    guard case .app(let first) = items[0], case .app(let second) = items[1] else {
        Issue.record("app 항목이 아님")
        return
    }
    #expect(first.app == AppID("cursor"))
    #expect(first.slot == .leftHalf)
    #expect(second.app == AppID("iterm"))
    #expect(second.slot == .full)
}

@Test func decodesBrowserItemWithTabs() throws {
    let config = try WorkspaceConfig.decode(yaml: sample)
    guard case .browser(let browser) = config.screens[1].items[0] else {
        Issue.record("browser 항목이 아님")
        return
    }
    #expect(browser.app == AppID("chrome"))
    #expect(browser.tabs.count == 2)
}

@Test func appliesDefaults() throws {
    let config = try WorkspaceConfig.decode(yaml: sample)
    let research = config.screens[1]
    #expect(research.display == .any)
    #expect(research.mode == .desktop)
    #expect(research.anchor == nil)
}

@Test func parsesDisplaySelectors() throws {
    let yaml = """
    workspace: x
    screens:
      - id: a
        display: builtin
        items: [{type: app, app: safari}]
      - id: b
        display: external-1
        items: [{type: app, app: safari}]
      - id: c
        display: external-2
        items: [{type: app, app: safari}]
      - id: d
        display: any
        items: [{type: app, app: safari}]
    """
    let config = try WorkspaceConfig.decode(yaml: yaml)
    #expect(config.screens.map(\.display) == [.builtin, .external(index: 1), .external(index: 2), .any])
}

@Test func rejectsInvalidSlot() {
    let yaml = """
    workspace: x
    screens:
      - id: a
        items: [{type: app, app: safari, slot: bogus}]
    """
    #expect(throws: ConfigError.self) { try WorkspaceConfig.decode(yaml: yaml) }
}

@Test func rejectsUnknownItemType() {
    let yaml = """
    workspace: x
    screens:
      - id: a
        items: [{type: widget, app: safari}]
    """
    #expect(throws: ConfigError.self) { try WorkspaceConfig.decode(yaml: yaml) }
}

@Test func rejectsInvalidDisplaySelector() {
    let yaml = """
    workspace: x
    screens:
      - id: a
        display: external-0
        items: [{type: app, app: safari}]
    """
    #expect(throws: ConfigError.self) { try WorkspaceConfig.decode(yaml: yaml) }
}

@Test func errorMessageKeepsPath() {
    let yaml = """
    workspace: x
    screens:
      - id: a
        items: [{type: app, app: safari, slot: bogus}]
    """
    do {
        _ = try WorkspaceConfig.decode(yaml: yaml)
        Issue.record("오류가 나지 않음")
    } catch {
        #expect("\(error)".contains("slot"))
    }
}

@Test func hideOthersDefaultsToOff() throws {
    #expect(try WorkspaceConfig.decode(yaml: sample).hideOthers == false)
}

@Test func hideOthersIsReadWhenDeclared() throws {
    let yaml = """
    workspace: dev
    hideOthers: true
    screens:
      - id: main
        items:
          - {type: app, app: safari}
    """
    #expect(try WorkspaceConfig.decode(yaml: yaml).hideOthers)
}

@Test func aBrowserCanAskForFullScreen() throws {
    let yaml = """
    workspace: web
    screens:
      - id: main
        items:
          - {type: browser, app: safari, fullscreen: true}
          - {type: browser, app: chrome}
    """
    let items = try WorkspaceConfig.decode(yaml: yaml).screens[0].items
    guard case .browser(let safari) = items[0], case .browser(let chrome) = items[1] else {
        Issue.record("브라우저 항목이 아닙니다")
        return
    }
    #expect(safari.fullscreen)
    #expect(!chrome.fullscreen)
}
