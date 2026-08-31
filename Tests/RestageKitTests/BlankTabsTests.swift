import Testing

@testable import RestageKit

@Test func startPagesCountAsBlank() {
    #expect(BlankTabs.isBlank("favorites://"))
    #expect(BlankTabs.isBlank("chrome://newtab/"))
    #expect(BlankTabs.isBlank("about:blank"))
    #expect(BlankTabs.isBlank(""))
    #expect(!BlankTabs.isBlank("https://example.com/"))
}

@Test func aWindowIsBlankOnlyWhenEveryTabIs() {
    #expect(BlankTabs.allBlank(["favorites://"]))
    #expect(BlankTabs.allBlank(["about:blank", "chrome://newtab/"]))
    #expect(!BlankTabs.allBlank(["favorites://", "https://example.com/"]))
    #expect(!BlankTabs.allBlank([]))
}
