import Testing
@testable import RestageKit

@Test func addsHTTPSWhenSchemeMissing() {
    #expect(URLNormalizer.normalize("example.com") == "https://example.com")
    #expect(URLNormalizer.normalize("example.com/path") == "https://example.com/path")
}

@Test func keepsExistingScheme() {
    #expect(URLNormalizer.normalize("http://example.com") == "http://example.com")
    #expect(URLNormalizer.normalize("https://example.com") == "https://example.com")
}

@Test func stripsTrailingSlash() {
    #expect(URLNormalizer.normalize("https://example.com/") == "https://example.com")
    #expect(URLNormalizer.normalize("https://example.com/path/") == "https://example.com/path")
}

@Test func lowercasesHostOnly() {
    #expect(URLNormalizer.normalize("https://Example.COM/Path") == "https://example.com/Path")
}

@Test func preservesQueryAndFragment() {
    #expect(URLNormalizer.normalize("https://example.com/a?x=1") == "https://example.com/a?x=1")
    #expect(URLNormalizer.normalize("https://example.com/a#top") == "https://example.com/a#top")
}

@Test func trailingSlashOnRootWithQueryIsKept() {
    #expect(URLNormalizer.normalize("https://example.com/?x=1") == "https://example.com/?x=1")
}

@Test func nonHTTPSchemesPassThrough() {
    #expect(URLNormalizer.normalize("favorites://") == "favorites://")
    #expect(URLNormalizer.normalize("file:///tmp/a.html") == "file:///tmp/a.html")
}

@Test func equalityIgnoresIncidentalDifferences() {
    #expect(URLNormalizer.normalize("Example.com/") == URLNormalizer.normalize("https://example.com"))
}

@Test func savesNormalWebAddresses() {
    #expect(URLNormalizer.isSavable("https://example.com"))
    #expect(URLNormalizer.isSavable("http://example.com/path?q=1"))
    #expect(URLNormalizer.isSavable("HTTPS://EXAMPLE.COM"))
}

@Test func savesSchemelessAddresses() {
    #expect(URLNormalizer.isSavable("example.com"))
    #expect(URLNormalizer.isSavable("example.com/path"))
}

@Test func skipsBrowserInternalPages() {
    #expect(!URLNormalizer.isSavable("favorites://"))
    #expect(!URLNormalizer.isSavable("chrome://newtab/"))
    #expect(!URLNormalizer.isSavable("about:blank"))
    #expect(!URLNormalizer.isSavable("file:///Users/me/x.html"))
    #expect(!URLNormalizer.isSavable(""))
    #expect(!URLNormalizer.isSavable("   "))
}
