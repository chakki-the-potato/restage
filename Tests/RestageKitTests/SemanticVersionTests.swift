import Testing
@testable import RestageKit

@Test func parsesPlainVersion() {
    let version = SemanticVersion("1.2.3")
    #expect(version == SemanticVersion(major: 1, minor: 2, patch: 3))
}

@Test func stripsLeadingV() {
    #expect(SemanticVersion("v0.1.0") == SemanticVersion(major: 0, minor: 1, patch: 0))
    #expect(SemanticVersion("V2.0.0") == SemanticVersion(major: 2, minor: 0, patch: 0))
}

@Test func fillsMissingParts() {
    #expect(SemanticVersion("1") == SemanticVersion(major: 1, minor: 0, patch: 0))
    #expect(SemanticVersion("1.5") == SemanticVersion(major: 1, minor: 5, patch: 0))
}

@Test func ignoresPreReleaseMarker() {
    #expect(SemanticVersion("1.2.3-beta.1") == SemanticVersion(major: 1, minor: 2, patch: 3))
    #expect(SemanticVersion("v1.0.0+build5") == SemanticVersion(major: 1, minor: 0, patch: 0))
}

@Test func rejectsNonVersions() {
    #expect(SemanticVersion("dev") == nil)
    #expect(SemanticVersion("") == nil)
    #expect(SemanticVersion("v") == nil)
}

@Test func comparesNumericallyNotLexically() {
    let ten = SemanticVersion("0.10.0")!
    let nine = SemanticVersion("0.9.0")!
    #expect(ten > nine)
    #expect(!(ten < nine))
}

@Test func comparesEachComponentInOrder() {
    #expect(SemanticVersion("2.0.0")! > SemanticVersion("1.99.99")!)
    #expect(SemanticVersion("1.2.10")! > SemanticVersion("1.2.9")!)
    #expect(SemanticVersion("1.2.3")! == SemanticVersion("1.2.3")!)
}

@Test func describesWithoutPrefix() {
    #expect(SemanticVersion("v1.2.3")!.description == "1.2.3")
}
