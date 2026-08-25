import CoreGraphics
import Testing

@testable import RestageKit

private let laptop = DisplayInfo(
    visibleFrame: CGRect(x: 0, y: 70, width: 1728, height: 1000), primaryMaxY: 1117)
private let external = DisplayInfo(
    visibleFrame: CGRect(x: -419, y: -1440, width: 2560, height: 1400), primaryMaxY: 1117)

private func resolve(_ yaml: String, displays: DisplayList) throws -> ResolvedWorkspace {
    WorkspaceResolver.resolve(try WorkspaceConfig.decode(yaml: yaml), displays: displays)
}

private let twoScreens = """
    workspace: w
    screens:
      - id: main
        display: builtin
        items: [{type: app, app: safari, slot: left-half}]
      - id: wide
        display: external-1
        whenMissing: fullscreen
        items:
          - {type: app, app: notion, slot: left-half}
          - {type: app, app: figma, slot: right-half}
    """

@Test func bothScreensAreUsedWhenBothDisplaysAreThere() throws {
    let resolved = try resolve(
        twoScreens, displays: DisplayList(primary: laptop, externals: [external]))
    #expect(resolved.screens.map(\.id) == ["main", "wide"])
    #expect(resolved.skipped.isEmpty)
    #expect(resolved.screens[1].mode == .desktop)
}

/// 모니터가 하나면 그 화면을 버리지 않는다. 주 모니터에서 전체화면으로 열어
/// macOS가 데스크탑을 하나씩 내주게 한다.
@Test func aMissingDisplayFallsBackToFullScreenOnThePrimary() throws {
    let resolved = try resolve(twoScreens, displays: DisplayList(primary: laptop, externals: []))
    #expect(resolved.skipped.isEmpty)
    #expect(resolved.screens.map(\.id) == ["main", "wide"])

    let wide = resolved.screens[1]
    #expect(wide.mode == .fullscreen)
    #expect(wide.items.count == 2)
}

/// whenMissing 을 적지 않으면 예전처럼 건너뛴다. 기존 설정이 깨지지 않아야 한다.
@Test func withoutThePolicyItStillSkips() throws {
    let yaml = """
        workspace: w
        screens:
          - id: wide
            display: external-1
            items: [{type: app, app: notion, slot: full}]
        """
    let resolved = try resolve(yaml, displays: DisplayList(primary: laptop, externals: []))
    #expect(resolved.screens.isEmpty)
    #expect(resolved.skipped.map(\.id) == ["wide"])
}

/// 세 화면을 저장했는데 모니터가 둘이면, 세 번째만 주 모니터로 떨어진다.
@Test func onlyTheScreensWithoutADisplayFallBack() throws {
    let yaml = """
        workspace: w
        screens:
          - id: one
            display: builtin
            items: [{type: app, app: safari, slot: full}]
          - id: two
            display: external-1
            whenMissing: fullscreen
            items: [{type: app, app: notion, slot: full}]
          - id: three
            display: external-2
            whenMissing: fullscreen
            items: [{type: app, app: figma, slot: full}]
        """
    let resolved = try resolve(yaml, displays: DisplayList(primary: laptop, externals: [external]))
    #expect(resolved.screens.map(\.id) == ["one", "two", "three"])
    #expect(resolved.screens[1].mode == .desktop)
    #expect(resolved.screens[2].mode == .fullscreen)
    #expect(resolved.screens[2].display.visibleFrame == laptop.visibleFrame)
}
