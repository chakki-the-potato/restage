import Testing
@testable import RestageKit

private func entry(_ name: String, error: String? = nil) -> WorkspaceEntry {
    WorkspaceEntry(
        name: name, path: "/tmp/\(name).yaml",
        screenCount: error == nil ? 1 : nil,
        itemCount: error == nil ? 2 : nil,
        error: error)
}

@Test func listsWorkspacesAsEnabledEntries() {
    let entries = MenuContent.entries(for: .success([entry("dev"), entry("research")]))
    #expect(entries == [.workspace(name: "dev"), .workspace(name: "research")])
    #expect(entries.filter { $0.isEnabled }.count == 2)
}

@Test func brokenWorkspaceIsDisabledAndKeepsReason() {
    let entries = MenuContent.entries(
        for: .success([entry("dev"), entry("broken", error: "slot 값이 올바르지 않습니다")]))
    #expect(entries.count == 2)
    #expect(entries[1] == .brokenWorkspace(name: "broken", reason: "slot 값이 올바르지 않습니다"))
    #expect(!entries[1].isEnabled)
    #expect(entries[1].tooltip == "slot 값이 올바르지 않습니다")
}

@Test func emptyDirectoryShowsNotice() {
    let entries = MenuContent.entries(for: .success([]))
    #expect(entries == [.notice("등록된 워크스페이스가 없습니다")])
    #expect(!entries[0].isEnabled)
}

@Test func registryFailureShowsFirstLineOnly() {
    let error = ConfigError.directoryNotFound(path: "/nope")
    let entries = MenuContent.entries(for: .failure(error))
    #expect(entries.count == 1)
    #expect(!entries[0].isEnabled)
    #expect(entries[0].title.contains("/nope"))
    #expect(!entries[0].title.contains("\n"))
}

@Test func failureSummaryIsNilWhenAllSucceeded() {
    let outcomes = [
        ItemOutcome(screenID: "main", app: AppID("safari"), status: .placed),
        ItemOutcome(screenID: "main", app: AppID("notion"), status: .alreadySatisfied),
        ItemOutcome(screenID: "main", app: AppID("xcode"), status: .constrained),
    ]
    #expect(MenuContent.failureSummary(outcomes) == nil)
}

@Test func failureSummaryListsOnlyFailures() {
    let outcomes = [
        ItemOutcome(screenID: "main", app: AppID("safari"), status: .placed),
        ItemOutcome(
            screenID: "main", app: AppID("nope"), status: .failed, detail: "레지스트리에 없는 앱"),
        ItemOutcome(screenID: "side", app: nil, status: .skipped, detail: "디스플레이 없음"),
    ]
    let summary = MenuContent.failureSummary(outcomes)
    #expect(summary?.contains("nope: 레지스트리에 없는 앱") == true)
    #expect(summary?.contains("side: 디스플레이 없음") == true)
    #expect(summary?.contains("safari") == false)
}
