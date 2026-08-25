import Testing

@testable import RestageKit

@Test func summaryIsNilWhenEverythingSucceeded() {
    let outcomes = [
        ItemOutcome(screenID: "main", app: AppID("safari"), status: .placed),
        ItemOutcome(screenID: "main", app: AppID("notion"), status: .alreadySatisfied),
        ItemOutcome(screenID: "main", app: AppID("xcode"), status: .constrained),
    ]
    #expect(RunFailures.summary(outcomes) == nil)
}

@Test func summaryListsOnlyTheFailures() {
    let outcomes = [
        ItemOutcome(screenID: "main", app: AppID("safari"), status: .placed),
        ItemOutcome(
            screenID: "main", app: AppID("nope"), status: .failed, detail: "레지스트리에 없는 앱"),
        ItemOutcome(screenID: "side", app: nil, status: .skipped, detail: "디스플레이 없음"),
    ]
    let summary = RunFailures.summary(outcomes)
    #expect(summary?.contains("nope: 레지스트리에 없는 앱") == true)
    #expect(summary?.contains("side: 디스플레이 없음") == true)
    #expect(summary?.contains("safari") == false)
}
