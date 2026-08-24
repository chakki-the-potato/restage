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

/// 제목이 비어 있어도 창이 하나면 담을 수 있다. 고를 필요가 없기 때문이다.
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

/// 제목이 전부 비면 골라낼 방법이 없다. 하나만 담고 나머지는 버린다.
/// 넷을 다 담으면 실행 때 같은 창을 네 번 옮기고 끝난다. 실제로 겪었다.
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

/// 고유한 제목이 섞여 있으면 그것만 담는다. 구분 못 하는 창을 함께 담으면 그것이
/// 제목 없는 선택자가 되어 이미 담은 창을 다시 가로챈다.
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

/// 같은 제목이라도 앱이 다르면 서로 상관없다.
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
