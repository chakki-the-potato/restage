import Testing

@testable import restage

@Test func homebrewCellarPathIsRecognized() {
    #expect(
        InstallSource.from(path: "/opt/homebrew/Cellar/restage/0.3.0/restage.app") == .homebrew)
    #expect(
        InstallSource.from(path: "/usr/local/Cellar/restage/0.3.0/restage.app") == .homebrew)
}

@Test func everywhereElseIsNotHomebrew() {
    #expect(InstallSource.from(path: "/Applications/restage.app") == .elsewhere)
    #expect(InstallSource.from(path: "/Users/me/build/restage.app") == .elsewhere)
}

@Test func anotherFormulaInCellarIsNotUs() {
    #expect(
        InstallSource.from(path: "/opt/homebrew/Cellar/other/1.0/restage.app") == .elsewhere)
}
