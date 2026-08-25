import Testing
@testable import RestageKit

@Test func acceptsOrdinaryNames() {
    #expect(WorkspaceName.validate("dev") == nil)
    #expect(WorkspaceName.validate("작업 공간") == nil)
    #expect(WorkspaceName.validate("dev-2") == nil)
    #expect(WorkspaceName.validate("dev_2") == nil)
}

@Test func rejectsPathLikeNames() {
    #expect(WorkspaceName.validate("a/b") != nil)
    #expect(WorkspaceName.validate("dev.yaml") != nil)
    #expect(WorkspaceName.validate(".hidden") != nil)
}

@Test func rejectsEmptyOrWhitespaceOnly() {
    #expect(WorkspaceName.validate("") != nil)
    #expect(WorkspaceName.validate("   ") != nil)
}

@Test func rejectsControlCharacters() {
    #expect(WorkspaceName.validate("dev\nprod") != nil)
    #expect(WorkspaceName.validate("dev\u{0}") != nil)
}

@Test func rejectsOverlyLongNames() {
    let long = String(repeating: "a", count: WorkspaceName.maxLength + 1)
    #expect(WorkspaceName.validate(long) != nil)
    #expect(WorkspaceName.validate(String(repeating: "a", count: WorkspaceName.maxLength)) == nil)
}

@Test func trimsSurroundingWhitespace() {
    #expect(WorkspaceName.validate("  dev  ") == nil)
    #expect(WorkspaceName.normalize("  dev  ") == "dev")
}
