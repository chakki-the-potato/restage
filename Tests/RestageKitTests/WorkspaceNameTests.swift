import Testing
@testable import RestageKit

@Test func acceptsOrdinaryNames() {
    #expect(WorkspaceName.validate("dev") == nil)
    #expect(WorkspaceName.validate("작업 공간") == nil)
    #expect(WorkspaceName.validate("dev-2") == nil)
    #expect(WorkspaceName.validate("dev_2") == nil)
}

/// 슬래시와 점을 막는 이유는 `WorkspaceRegistry.resolve`가 그것으로 이름과 경로를 가르기
/// 때문이다. 통과시키면 엉뚱한 파일을 연다.
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

/// 앞뒤 공백은 사유가 아니라 정리 대상이다. 사용자가 붙여넣기로 흘리는 값이다.
@Test func trimsSurroundingWhitespace() {
    #expect(WorkspaceName.validate("  dev  ") == nil)
    #expect(WorkspaceName.normalize("  dev  ") == "dev")
}
