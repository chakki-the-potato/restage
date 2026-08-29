import Testing

@testable import restage

@MainActor
@Test func typingPartOfANameFindsTheApp() {
    let names = AppChooser.suggestions(for: "saf", browsersOnly: false).map(\.name)
    #expect(names.contains("Safari"))
}

@MainActor
@Test func nothingIsSuggestedForAnEmptyQuery() {
    #expect(AppChooser.suggestions(for: "  ", browsersOnly: false).isEmpty)
}

@MainActor
@Test func theListNeverGrowsPastTheLimit() {
    let many = AppChooser.suggestions(for: "a", browsersOnly: false)
    #expect(many.count <= AppChooser.suggestionLimit)
}

@MainActor
@Test func webModeOnlyOffersBrowsers() {
    let notes = AppChooser.suggestions(for: "notes", browsersOnly: true).map(\.name)
    #expect(!notes.contains("Notes"))
    #expect(AppChooser.suggestions(for: "safari", browsersOnly: true).map(\.name) == ["Safari"])
}

@MainActor
@Test func anAbsoluteBundlePathBecomesTheAppName() {
    #expect(AppChooser.appName(fromPath: "/Applications/Safari.app") == "Safari")
    #expect(AppChooser.appName(fromPath: "/System/Applications/Books.app") == "Books")
}

@MainActor
@Test func aPathThatLostItsLeadingSlashStillResolves() {
    #expect(AppChooser.appName(fromPath: "Applications/Safari.app") == "Safari")
    #expect(AppChooser.appName(fromPath: " /Applications/Safari.app ") == "Safari")
}

@MainActor
@Test func aPlainNameIsNotAPath() {
    #expect(AppChooser.appName(fromPath: "Safari") == nil)
    #expect(AppChooser.appName(fromPath: "") == nil)
}

@MainActor
@Test func aPathToNothingResolvesToNothing() {
    #expect(AppChooser.appName(fromPath: "/Applications/NoSuchApp.app") == nil)
}
