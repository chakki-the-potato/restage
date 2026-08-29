import Testing
@testable import RestageKit

private func draft(_ items: [ItemDraft]) -> WorkspaceDraft {
    WorkspaceDraft(name: "w", screens: [ScreenDraft(id: "main", display: .builtin, items: items)])
}

private func labels(_ items: [ItemDraft]) -> [String] {
    DraftSelection.entries(in: draft(items)).map { DraftSelection.label(for: $0) }
}

/// 같은 앱의 이름 없는 창은 번호로 부른다. 실행할 때 그 순서대로 자리를 잡으므로
/// 번호가 곧 사실이다.
@Test func unnamedWindowsOfOneAppAreNumbered() {
    #expect(labels([
        .app("Claude", slot: .q1), .app("Claude", slot: .q2), .app("Claude", slot: .q3),
    ]) == ["Claude 1", "Claude 2", "Claude 3"])
}

@Test func aLoneWindowGetsNoNumber() {
    #expect(labels([.app("Claude", slot: .full), .app("Notion", slot: .full)])
        == ["Claude", "Notion"])
}

@Test func titledWindowsShowTheirTitleAndDoNotCountTowardNumbering() {
    #expect(labels([
        .app("Cursor", slot: .q1, title: "restage"),
        .app("Cursor", slot: .q2),
        .app("Cursor", slot: .q3),
    ]) == ["Cursor · restage", "Cursor 1", "Cursor 2"])
}

@Test func browsersWithoutAddressesAreNumberedToo() {
    #expect(labels([
        .browser("Safari", slot: .leftHalf, tabs: []),
        .browser("Safari", slot: .rightHalf, tabs: []),
        .browser("Safari", slot: .full, tabs: ["https://example.com/"]),
    ]) == ["Safari 1", "Safari 2", "Safari"])
}

@Test func editedTabsReplaceTheSavedOnes() {
    let original = draft([
        .browser("Safari", slot: .full, tabs: []),
        .app("Notion", slot: .full),
    ])
    let edited = DraftSelection.apply(
        excluding: [], tabs: [0: ["https://a.com/", "https://b.com/"], 1: ["https://x.com/"]],
        to: original)
    #expect(edited.screens[0].items[0].tabs == ["https://a.com/", "https://b.com/"])
    #expect(edited.screens[0].items[1].tabs.isEmpty)
    #expect(!edited.screens[0].items[1].isBrowser)
}
