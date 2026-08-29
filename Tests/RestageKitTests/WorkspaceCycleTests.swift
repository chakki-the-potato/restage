import Testing

@testable import RestageKit

private let names = ["dev", "morning", "research"]

@Test func theFirstRunStartsAtTheTop() {
    #expect(WorkspaceCycle.next(after: nil, in: names) == "dev")
}

@Test func eachOneLeadsToTheNext() {
    #expect(WorkspaceCycle.next(after: "dev", in: names) == "morning")
    #expect(WorkspaceCycle.next(after: "morning", in: names) == "research")
}

@Test func theLastOneWrapsAround() {
    #expect(WorkspaceCycle.next(after: "research", in: names) == "dev")
}

@Test func anEmptyListHasNoNextAndAStrangerStartsOver() {
    #expect(WorkspaceCycle.next(after: "dev", in: []) == nil)
    #expect(WorkspaceCycle.next(after: nil, in: []) == nil)
    #expect(WorkspaceCycle.next(after: "deleted", in: names) == "dev")
}
