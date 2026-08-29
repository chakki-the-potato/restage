import RestageKit
import Testing

@testable import restage

@Test func theBuiltInDisplayAndAnyAreTheSameScreen() {
    #expect(ScreenLabel.text(.builtin) == ScreenLabel.text(.any))
}

@Test func externalDisplaysAreCountedAfterTheMainOne() {
    #expect(ScreenLabel.text(.external(index: 1)).contains("2"))
    #expect(ScreenLabel.text(.external(index: 2)).contains("3"))
}

@Test func anExternalDisplayIsNotCalledTheMainOne() {
    #expect(ScreenLabel.text(.external(index: 1)) != ScreenLabel.text(.builtin))
}
