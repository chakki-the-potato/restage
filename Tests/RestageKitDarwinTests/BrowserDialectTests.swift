import CoreGraphics
import Testing
import RestageKit
@testable import RestageKitDarwin

// 스크립트 생성은 순수하므로 방언을 직접 만들어 검증한다. 설치된 앱에 기대면
// 검증 결과가 검증하는 사람의 컴퓨터에 좌우된다.
private let safari = BrowserDialect(applicationName: "Safari", makesWindowWithURL: true)
private let chrome = BrowserDialect(applicationName: "Google Chrome", makesWindowWithURL: false)
private let edge = BrowserDialect(applicationName: "Microsoft Edge", makesWindowWithURL: false)

@Test func readTabsScriptNamesTheApplication() {
    #expect(safari.readWindowsScript().contains(#"tell application "Safari""#))
    #expect(chrome.readWindowsScript().contains(#"tell application "Google Chrome""#))
    #expect(edge.readWindowsScript().contains(#"tell application "Microsoft Edge""#))
}

/// 구분자를 tell 블록 안에서 만들면 `tab`이 브라우저의 tab 클래스로 해석돼 파싱이 전부 깨진다.
@Test func separatorsAreDefinedOutsideTellBlock() {
    let script = safari.readWindowsScript()
    let separatorLine = script.range(of: "set fieldSeparator to character id 9")
    let tellLine = script.range(of: #"tell application"#)
    #expect(separatorLine != nil)
    #expect(tellLine != nil)
    #expect(separatorLine!.lowerBound < tellLine!.lowerBound)
}

@Test func geometryScriptReadsBoundsNotID() {
    #expect(safari.readWindowGeometryScript().contains("bounds of w"))
    #expect(!safari.readWindowGeometryScript().contains("id of w"))
}

@Test func newWindowScriptDiffersByBrowserFamily() {
    #expect(safari.newWindowScript(url: "https://example.com").contains("make new document"))
    #expect(chrome.newWindowScript(url: "https://example.com").contains("make new window"))
    #expect(edge.newWindowScript(url: "https://example.com").contains("make new window"))
}

@Test func addTabScriptCarriesWindowIDAndURL() {
    let script = safari.addTabScript(windowID: 42, url: "https://example.com/x")
    #expect(script.contains("42"))
    #expect(script.contains("https://example.com/x"))
}

@Test func escapesQuotesInURL() {
    let script = safari.addTabScript(windowID: 1, url: #"https://example.com/"q""#)
    #expect(script.contains(#"https://example.com/\"q\""#))
}

/// Safari는 모든 macOS에 있으므로 해석 경로를 이것으로만 확인한다.
@Test @MainActor func resolvesSafariFromInstalledApps() throws {
    let dialect = try BrowserDialect.forApp(AppID("safari"))
    #expect(dialect.applicationName == "Safari")
    #expect(dialect.makesWindowWithURL)
}

@Test @MainActor func unknownAppNameFails() {
    #expect(throws: EngineError.self) {
        try BrowserDialect.forApp(AppID("definitely-not-an-installed-app"))
    }
}

// MARK: - 창 좌표 대응

private let browserWindows = [
    CapturedBrowserWindow(
        frame: CGRect(x: 0, y: 33, width: 864, height: 1026),
        tabs: ["https://example.com/"]),
    CapturedBrowserWindow(
        frame: CGRect(x: 864, y: 33, width: 864, height: 1026),
        tabs: ["https://example.org/"]),
]

@Test func matchesWindowByFrame() {
    let right = CGRect(x: 864, y: 33, width: 864, height: 1026)
    #expect(BrowserSnapshot.index(matching: right, in: browserWindows) == 1)
}

/// 창 테두리 계산이 한두 픽셀 어긋나도 같은 창으로 봐야 한다.
@Test func smallDifferenceStillMatches() {
    let nudged = CGRect(x: 1, y: 34, width: 863, height: 1027)
    #expect(BrowserSnapshot.index(matching: nudged, in: browserWindows) == 0)
}

@Test func differentFrameDoesNotMatch() {
    let elsewhere = CGRect(x: 400, y: 400, width: 300, height: 300)
    #expect(BrowserSnapshot.index(matching: elsewhere, in: browserWindows) == nil)
    #expect(BrowserSnapshot.index(matching: .zero, in: []) == nil)
}

// MARK: - 출력 파싱

/// 앞 네 칸이 bounds이고 나머지가 탭이다. bounds는 좌·상·우·하이므로 폭과 높이로 바꾼다.
@Test func parsesBoundsAndTabs() {
    let raw = "0\t33\t864\t1059\thttps://example.com/\thttps://example.org/\n"
    let windows = BrowserSnapshot.parse(raw)
    #expect(windows.count == 1)
    #expect(windows[0].frame == CGRect(x: 0, y: 33, width: 864, height: 1026))
    #expect(windows[0].tabs == ["https://example.com/", "https://example.org/"])
}

@Test func parsesWindowWithoutTabs() {
    let windows = BrowserSnapshot.parse("100\t200\t300\t400\n")
    #expect(windows.count == 1)
    #expect(windows[0].tabs.isEmpty)
}

/// 외장 디스플레이는 좌표가 음수다. 부호를 잃으면 화면 배정이 어긋난다.
@Test func parsesNegativeCoordinates() {
    let windows = BrowserSnapshot.parse("861\t-1410\t2141\t0\thttps://example.com/\n")
    #expect(windows[0].frame == CGRect(x: 861, y: -1410, width: 1280, height: 1410))
}

@Test func ignoresMalformedLines() {
    #expect(BrowserSnapshot.parse("").isEmpty)
    #expect(BrowserSnapshot.parse("1\t2\t3\n").isEmpty)
    #expect(BrowserSnapshot.parse("a\tb\tc\td\n").isEmpty)
}
