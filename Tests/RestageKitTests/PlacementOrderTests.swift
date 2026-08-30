import CoreGraphics
import Testing

@testable import RestageKit

private func titled(_ app: String, _ title: String) -> PlannedItem {
    .place(Placement(
        app: AppID(app), slot: .full, target: .zero,
        selector: WindowSelector(titleContains: title)))
}

private func untitled(_ app: String) -> PlannedItem {
    .place(Placement(app: AppID(app), slot: .full, target: .zero))
}

private func tabs(_ app: String) -> PlannedItem {
    .tabs(TabPlan(
        app: AppID(app), window: .separate, slot: .full, target: .zero,
        tabs: ["https://example.com"]))
}

@Test func aNamedWindowIsClaimedFirst() {
    let items = [untitled("Chrome"), titled("Chrome", "Docs")]
    #expect(PlacementOrder.sorted([0, 1], in: items) == [1, 0])
}

@Test func aBrowserOpensItsWindowsBeforeTheUnnamedItemsTakeThem() {
    let items = [untitled("Chrome"), tabs("Chrome"), untitled("Chrome")]
    #expect(PlacementOrder.sorted([0, 1, 2], in: items) == [1, 0, 2])
}

@Test func theWholeOrderIsNamedThenBrowserThenUnnamed() {
    let items = [untitled("Chrome"), tabs("Chrome"), titled("Chrome", "Docs")]
    #expect(PlacementOrder.sorted([0, 1, 2], in: items) == [2, 1, 0])
}

@Test func itemsOfOneKindStayInTheOrderTheyWereWritten() {
    let items = [untitled("Chrome"), untitled("Chrome"), untitled("Chrome")]
    #expect(PlacementOrder.sorted([0, 1, 2], in: items) == [0, 1, 2])
    #expect(PlacementOrder.sorted([2, 0, 1], in: items) == [0, 1, 2])
}
