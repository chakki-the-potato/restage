import Testing
@testable import RestageKit

private func candidates(_ pairs: [(String, String)]) -> [WindowIdentity.Candidate] {
    pairs.map { WindowIdentity.Candidate(app: $0.0, title: $0.1) }
}

@Test func singleWindowNeedsNoTitle() {
    let result = WindowIdentity.select(candidates([("Safari", "시작 페이지")]))
    #expect(result.kept == [0])
    #expect(result.needsTitle.isEmpty)
    #expect(result.byOrderByApp.isEmpty)
}

@Test func distinctTitlesAreAllKeptWithTitles() {
    let result = WindowIdentity.select(
        candidates([("Cursor", "restage"), ("Cursor", "internkim")]))
    #expect(result.kept == [0, 1])
    #expect(result.needsTitle == [0, 1])
    #expect(result.byOrderByApp.isEmpty)
}

/// 제목으로 못 가르는 창도 버리지 않는다. 순서대로 자리를 잡는다.
@Test func indistinguishableWindowsAreAllKeptByOrder() {
    let result = WindowIdentity.select(
        candidates([("Claude", ""), ("Claude", ""), ("Claude", ""), ("Claude", "")]))
    #expect(result.kept == [0, 1, 2, 3])
    #expect(result.needsTitle.isEmpty)
    #expect(result.byOrderByApp == ["Claude": 4])
}

@Test func duplicateTitlesGoByOrder() {
    let result = WindowIdentity.select(
        candidates([("Safari", "Example Domain"), ("Safari", "Example Domain")]))
    #expect(result.kept == [0, 1])
    #expect(result.needsTitle.isEmpty)
    #expect(result.byOrderByApp == ["Safari": 2])
}

/// 제목이 있는 창은 제목으로, 없는 창은 순서로. 섞여도 된다.
@Test func mixedTitlesKeepEveryoneAndTitleTheIdentifiableOnes() {
    let result = WindowIdentity.select(
        candidates([("Safari", "문서"), ("Safari", ""), ("Safari", "메일")]))
    #expect(result.kept == [0, 1, 2])
    #expect(result.needsTitle == [0, 2])
    #expect(result.byOrderByApp == ["Safari": 1])
}

@Test func differentAppsDoNotInterfere() {
    let result = WindowIdentity.select(
        candidates([("Safari", ""), ("Notion", ""), ("iTerm", "")]))
    #expect(result.kept == [0, 1, 2])
    #expect(result.byOrderByApp.isEmpty)
}

@Test func sameTitleAcrossAppsIsFine() {
    let result = WindowIdentity.select(
        candidates([("Safari", "GitHub"), ("Google Chrome", "GitHub")]))
    #expect(result.kept == [0, 1])
    #expect(result.needsTitle.isEmpty)
}

@Test func emptyInputYieldsEmptySelection() {
    let result = WindowIdentity.select([])
    #expect(result.kept.isEmpty)
    #expect(result.byOrderByApp.isEmpty)
}
