import Testing
import CoreGraphics
@testable import RestageKit

private let display = DisplayInfo(
    visibleFrame: CGRect(x: 0, y: 57, width: 1728, height: 1027), primaryMaxY: 1117)
private let displays = DisplayList(primary: display, externals: [])

private func resolve(_ yaml: String) throws -> ResolvedWorkspace {
    WorkspaceResolver.resolve(
        try ConfigLoader.validated(WorkspaceConfig.decode(yaml: yaml)), displays: displays)
}

private func placements(_ result: ResolvedWorkspace) -> [Placement] {
    result.screens.flatMap { screen in
        screen.items.compactMap { item in
            if case .place(let placement) = item { return placement }
            return nil
        }
    }
}

@Test func appItemWithoutTitleUsesMostRecentlyActive() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: main
        items: [{type: app, app: safari, slot: left-half}]
    """)
    #expect(placements(result)[0].selector == .mostRecentlyActive)
    #expect(placements(result)[0].selector.titleContains == nil)
}

@Test func appItemCarriesTitleIntoSelector() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: main
        items:
          - {type: app, app: safari, slot: left-half, title: 시작 페이지}
    """)
    #expect(placements(result)[0].selector.titleContains == "시작 페이지")
}

@Test func titleIsIndependentPerItem() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: main
        items:
          - {type: app, app: safari, slot: left-half, title: 시작 페이지}
          - {type: app, app: safari, slot: right-half}
    """)
    let all = placements(result)
    #expect(all.count == 2)
    #expect(all[0].selector.titleContains == "시작 페이지")
    #expect(all[1].selector.titleContains == nil)
}

@Test func placementDefaultsToMostRecentlyActive() {
    let placement = Placement(app: AppID("safari"), slot: .full, target: .zero)
    #expect(placement.selector == .mostRecentlyActive)
}

@Test func noWindowMatchingTitleErrorListsAvailableTitles() {
    let error = EngineError.noWindowMatchingTitle(
        pid: 1, wanted: "설정", available: ["시작 페이지", "Example Domain"])
    let text = "\(error)"
    #expect(text.contains("설정"))
    #expect(text.contains("시작 페이지"))
    #expect(text.contains("Example Domain"))
}

@Test func noWindowMatchingTitleErrorHandlesEmptyList() {
    let error = EngineError.noWindowMatchingTitle(pid: 1, wanted: "설정", available: [])
    #expect("\(error)".contains(L10n.string("error.engine.no_windows_open")))
}
