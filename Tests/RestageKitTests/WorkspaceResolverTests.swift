import Testing
import CoreGraphics
@testable import RestageKit

// 내장 1728x1117, 가용 영역 (0,57,1728,1027). 외장 2560x1440이 내장 위쪽에 배치.
private let builtin = DisplayInfo(
    visibleFrame: CGRect(x: 0, y: 57, width: 1728, height: 1027), primaryMaxY: 1117)
private let external = DisplayInfo(
    visibleFrame: CGRect(x: -419, y: 1117, width: 2560, height: 1440), primaryMaxY: 1117)

private let singleDisplay = DisplayList(primary: builtin, externals: [])
private let twoDisplays = DisplayList(primary: builtin, externals: [external])

private func resolve(_ yaml: String, _ displays: DisplayList) throws -> ResolvedWorkspace {
    WorkspaceResolver.resolve(
        try ConfigLoader.validated(WorkspaceConfig.decode(yaml: yaml)), displays: displays)
}

@Test func resolvesBuiltinToPrimary() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: code
        display: builtin
        items: [{type: app, app: safari, slot: left-half}]
    """, twoDisplays)
    #expect(result.screens.count == 1)
    #expect(result.screens[0].placements[0].target
        == SlotGeometry.frame(for: .leftHalf, in: builtin.visibleFrame, primaryMaxY: 1117))
}

@Test func resolvesAnyToPrimary() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: code
        display: any
        items: [{type: app, app: safari, slot: full}]
    """, twoDisplays)
    #expect(result.screens[0].display.visibleFrame == builtin.visibleFrame)
}

@Test func resolvesExternalOne() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: side
        display: external-1
        items: [{type: app, app: safari, slot: full}]
    """, twoDisplays)
    #expect(result.screens[0].display.visibleFrame == external.visibleFrame)
    #expect(result.screens[0].placements[0].target
        == SlotGeometry.frame(for: .full, in: external.visibleFrame, primaryMaxY: 1117))
}

@Test func externalTargetHasNegativeAXY() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: side
        display: external-1
        items: [{type: app, app: safari, slot: full}]
    """, twoDisplays)
    #expect(result.screens[0].placements[0].target.minY < 0)
}

@Test func skipsScreenWhenDisplayMissing() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: code
        display: builtin
        items: [{type: app, app: safari, slot: full}]
      - id: side
        display: external-1
        items: [{type: app, app: iterm, slot: full}]
    """, singleDisplay)
    #expect(result.screens.count == 1)
    #expect(result.screens[0].id == "code")
    #expect(result.skipped.count == 1)
    #expect(result.skipped[0].id == "side")
}

@Test func keepsRemainingScreensWhenOneIsSkipped() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: missing
        display: external-2
        items: [{type: app, app: safari, slot: full}]
      - id: code
        display: builtin
        items: [{type: app, app: iterm, slot: full}]
    """, twoDisplays)
    #expect(result.skipped.map(\.id) == ["missing"])
    #expect(result.screens.map(\.id) == ["code"])
}

@Test func browserItemsBecomeUnsupported() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: web
        items:
          - {type: app, app: safari, slot: left-half}
          - type: browser
            app: chrome
            tabs: [https://example.com]
    """, singleDisplay)
    #expect(result.screens[0].placements.count == 1)
    #expect(result.screens[0].unsupported.count == 1)
    #expect(result.screens[0].unsupported[0].app == AppID("chrome"))
}

@Test func preservesItemOrder() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: code
        items:
          - {type: app, app: safari, slot: left-half}
          - {type: app, app: iterm, slot: right-half}
          - {type: app, app: notion, slot: q1}
    """, singleDisplay)
    #expect(result.screens[0].placements.map(\.app.rawValue) == ["safari", "iterm", "notion"])
}

@Test func carriesModeAndAnchor() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: code
        mode: fullscreen
        anchor: safari
        items: [{type: app, app: safari, slot: full}]
    """, singleDisplay)
    #expect(result.screens[0].mode == .fullscreen)
    #expect(result.screens[0].anchor == AppID("safari"))
}

@Test func allScreensSkippedYieldsEmptyPlan() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: side
        display: external-1
        items: [{type: app, app: safari, slot: full}]
    """, singleDisplay)
    #expect(result.screens.isEmpty)
    #expect(result.skipped.count == 1)
}

@Test func twoScreensMayTargetSameDisplay() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: a
        display: builtin
        items: [{type: app, app: safari, slot: left-half}]
      - id: b
        display: builtin
        items: [{type: app, app: iterm, slot: right-half}]
    """, singleDisplay)
    #expect(result.screens.count == 2)
    #expect(result.skipped.isEmpty)
}
