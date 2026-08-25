import Testing
@testable import RestageKit

private func candidates(_ pairs: [(String, String)]) -> [WindowIdentity.Candidate] {
    pairs.map { WindowIdentity.Candidate(app: $0.0, title: $0.1) }
}

@Test func singleWindowNeedsNoTitle() {
    let result = WindowIdentity.select(candidates([("Safari", "시작 페이지")]))
    #expect(result.kept == [0])
    #expect(result.needsTitle.isEmpty)
    #expect(result.droppedByApp.isEmpty)
}

@Test func singleWindowWithoutTitleIsKept() {
    let result = WindowIdentity.select(candidates([("Claude", "")]))
    #expect(result.kept == [0])
    #expect(result.needsTitle.isEmpty)
}

@Test func distinctTitlesAreAllKeptWithTitles() {
    let result = WindowIdentity.select(
        candidates([("Cursor", "restage"), ("Cursor", "internkim")]))
    #expect(result.kept == [0, 1])
    #expect(result.needsTitle == [0, 1])
    #expect(result.droppedByApp.isEmpty)
}

@Test func indistinguishableWindowsKeepOnlyOne() {
    let result = WindowIdentity.select(
        candidates([("Claude", ""), ("Claude", ""), ("Claude", ""), ("Claude", "")]))
    #expect(result.kept == [0])
    #expect(result.needsTitle.isEmpty)
    #expect(result.droppedByApp == ["Claude": 3])
}

@Test func duplicateTitlesAreIndistinguishable() {
    let result = WindowIdentity.select(
        candidates([("Safari", "Example Domain"), ("Safari", "Example Domain")]))
    #expect(result.kept == [0])
    #expect(result.droppedByApp == ["Safari": 1])
}

@Test func mixedTitlesKeepOnlyIdentifiableOnes() {
    let result = WindowIdentity.select(
        candidates([("Safari", "문서"), ("Safari", ""), ("Safari", "메일")]))
    #expect(result.kept == [0, 2])
    #expect(result.needsTitle == [0, 2])
    #expect(result.droppedByApp == ["Safari": 1])
}

@Test func differentAppsDoNotInterfere() {
    let result = WindowIdentity.select(
        candidates([("Safari", ""), ("Notion", ""), ("iTerm", "")]))
    #expect(result.kept == [0, 1, 2])
    #expect(result.droppedByApp.isEmpty)
}

@Test func sameTitleAcrossAppsIsFine() {
    let result = WindowIdentity.select(
        candidates([("Safari", "GitHub"), ("Google Chrome", "GitHub")]))
    #expect(result.kept == [0, 1])
    #expect(result.needsTitle.isEmpty)
}

@Test func keptPreservesInputOrder() {
    let result = WindowIdentity.select(
        candidates([("A", "1"), ("B", ""), ("A", "2"), ("C", ""), ("A", "3")]))
    #expect(result.kept == [0, 1, 2, 3, 4])
}

@Test func emptyInputYieldsEmptySelection() {
    let result = WindowIdentity.select([])
    #expect(result.kept.isEmpty)
    #expect(result.droppedByApp.isEmpty)
}
