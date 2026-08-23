import Testing
import RestageKit
@testable import RestageKitDarwin

@Test func recognizesSupportedBrowsers() {
    #expect(BrowserDialect.forApp(AppID("safari")) != nil)
    #expect(BrowserDialect.forApp(AppID("chrome")) != nil)
    #expect(BrowserDialect.forApp(AppID("Safari")) != nil)
    #expect(BrowserDialect.forApp(AppID("notion")) == nil)
}

@Test func readTabsScriptNamesTheApplication() {
    let safari = BrowserDialect.forApp(AppID("safari"))!
    #expect(safari.readWindowsScript().contains(#"tell application "Safari""#))
    let chrome = BrowserDialect.forApp(AppID("chrome"))!
    #expect(chrome.readWindowsScript().contains(#"tell application "Google Chrome""#))
}

@Test func newWindowScriptDiffersByBrowser() {
    let safari = BrowserDialect.forApp(AppID("safari"))!
    #expect(safari.newWindowScript(url: "https://example.com").contains("make new document"))
    let chrome = BrowserDialect.forApp(AppID("chrome"))!
    #expect(chrome.newWindowScript(url: "https://example.com").contains("make new window"))
}

@Test func addTabScriptCarriesWindowIDAndURL() {
    let safari = BrowserDialect.forApp(AppID("safari"))!
    let script = safari.addTabScript(windowID: 42, url: "https://example.com/x")
    #expect(script.contains("42"))
    #expect(script.contains("https://example.com/x"))
}

@Test func escapesQuotesInURL() {
    let safari = BrowserDialect.forApp(AppID("safari"))!
    let script = safari.addTabScript(windowID: 1, url: #"https://example.com/"q""#)
    #expect(script.contains(#"https://example.com/\"q\""#))
}
