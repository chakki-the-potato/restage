import Testing

@testable import restage

@Test func anAddressWithoutASchemeIsStillAnAddress() {
    #expect(!DraftTabs.isMalformed("example.com/docs"))
    #expect(!DraftTabs.isMalformed("https://github.com/"))
}

@Test func textThatCannotBecomeAnAddressIsMarked() {
    #expect(DraftTabs.isMalformed("not a url"))
    #expect(DraftTabs.isMalformed("ftp://example.com"))
}

@Test func anEmptyLineIsNotMarked() {
    #expect(!DraftTabs.isMalformed(""))
    #expect(!DraftTabs.isMalformed("   "))
}

@Test func closingDropsBlanksAndNormalizesWhatItCan() {
    let cleaned = DraftTabs.cleaned(["  example.com/  ", "", "not a url", "https://github.com"])
    #expect(cleaned == ["https://example.com", "not a url", "https://github.com"])
}
