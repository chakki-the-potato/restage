import Testing

@testable import RestageKit

private func summary(_ yaml: String) throws -> WorkspaceSummary {
    WorkspaceSummary(config: try WorkspaceConfig.decode(yaml: yaml))
}

private func screen(_ items: String, mode: String = "desktop") -> String {
    """
    workspace: w
    screens:
      - id: main
        mode: \(mode)
        items: [\(items)]
    """
}

@Test func halvesAreReadAsALeftRightSplit() throws {
    let shape = try summary(
        screen("{type: app, app: safari, slot: left-half}, {type: app, app: notion, slot: right-half}")
    ).shape
    #expect(shape == .leftRight)
}

@Test func topAndBottomHalvesAreTheirOwnShape() throws {
    let shape = try summary(
        screen("{type: app, app: safari, slot: top-half}, {type: app, app: notion, slot: bottom-half}")
    ).shape
    #expect(shape == .topBottom)
}

@Test func fourQuartersAreReadAsQuarters() throws {
    let items = ["q1", "q2", "q3", "q4"].enumerated()
        .map { "{type: app, app: app\($0.offset), slot: \($0.element)}" }
        .joined(separator: ", ")
    #expect(try summary(screen(items)).shape == .quarters)
}

@Test func oneWindowFillingTheScreenIsFullScreen() throws {
    #expect(try summary(screen("{type: app, app: safari, slot: full}")).shape == .fullScreen)
}

@Test func fullscreenScreenModeIsFullScreenWhateverTheSlots() throws {
    let shape = try summary(
        screen("{type: app, app: safari, slot: left-half}", mode: "fullscreen")).shape
    #expect(shape == .fullScreen)
}

@Test func oneWindowInAHalfKeepsTheSlotName() throws {
    #expect(try summary(screen("{type: app, app: safari, slot: left-half}")).shape
        == .single(.leftHalf))
}

@Test func threeDistinctSlotsAreCountedAsPanes() throws {
    let shape = try summary(screen("""
        {type: app, app: a, slot: left-half}, {type: app, app: b, slot: q2}, \
        {type: app, app: c, slot: q4}
        """)).shape
    #expect(shape == .panes(3))
}

@Test func itemsWithoutASlotLeaveTheShapeUnknown() throws {
    let shape = try summary(screen("{type: browser, app: safari, tabs: [https://a.dev]}")).shape
    #expect(shape == .mixed)
}

@Test func appsKeepTheirOrderAndAppearOnce() throws {
    let config = """
        workspace: w
        screens:
          - id: main
            items:
              - {type: app, app: safari, slot: left-half}
              - {type: app, app: notion, slot: right-half}
          - id: second
            items:
              - {type: app, app: safari, slot: full}
        """
    #expect(try summary(config).apps == [AppID("safari"), AppID("notion")])
}

@Test func screensAndItemsAreCountedAcrossEveryScreen() throws {
    let config = """
        workspace: w
        screens:
          - id: main
            items: [{type: app, app: safari, slot: full}]
          - id: second
            items: [{type: app, app: notion, slot: full}, {type: app, app: music, slot: full}]
        """
    let result = try summary(config)
    #expect(result.screenCount == 2)
    #expect(result.itemCount == 3)
}
