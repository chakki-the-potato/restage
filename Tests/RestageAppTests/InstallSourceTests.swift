import Testing

@testable import restage

@Test func homebrewCellarPathIsRecognized() {
    #expect(
        InstallSource.from(path: "/opt/homebrew/Cellar/restage/0.3.0/restage.app") == .homebrew)
    #expect(
        InstallSource.from(path: "/usr/local/Cellar/restage/0.3.0/restage.app") == .homebrew)
}

/// cask와 설치 스크립트는 /Applications에 둔다. 그쪽은 릴리스 페이지로 안내해야 한다.
@Test func everywhereElseIsNotHomebrew() {
    #expect(InstallSource.from(path: "/Applications/restage.app") == .elsewhere)
    #expect(InstallSource.from(path: "/Users/me/build/restage.app") == .elsewhere)
}

/// Cellar 아래여도 다른 수식의 앱이면 우리 것이 아니다.
@Test func anotherFormulaInCellarIsNotUs() {
    #expect(
        InstallSource.from(path: "/opt/homebrew/Cellar/other/1.0/restage.app") == .elsewhere)
}
