# 브라우저 탭 제어 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** config의 `type: browser` 항목을 실행해 선언한 URL을 탭으로 열고, 필요하면 그 창도 배치한다.

**Architecture:** 아무것도 닫지 않는다. 대상 창을 찾아 없는 탭만 추가한다. 창 식별은 config의 첫 URL을 첫 탭으로 가진 창을 찾는 방식이다. 브라우저별 AppleScript 방언 차이는 한 파일에 가둔다.

**Tech Stack:** Swift 6.3, SwiftPM, swift-testing, Yams, NSAppleScript, ApplicationServices, AppKit.

**Spec:** `docs/superpowers/specs/2026-08-23-browser-tabs-design.md`

**Branch:** `feat/browser-tabs` (PR #2의 `feat/workspace-runner` 위에 쌓임)

---

## 사전 확인 사항 (환경 검증 완료)

실제로 확인한 사실이다.

**1. Safari와 Chrome 모두 AppleScript로 탭을 읽을 수 있다.** 이 머신에서는 Apple Events 권한이 이미 승인되어 있어 권한 거부(-1743) 경로는 직접 재현하지 못했다. 코드는 그 경로를 다루되 검증은 코드 리뷰로 대신한다.

**2. `make new document`로 만든 Safari 창은 맨 앞으로 오지 않는다.** 이것이 이 태스크에서 가장 중요한 함정이다. 실제로 확인한 결과다.

```
make new document with properties {URL:"https://example.com/a"} 실행 후
  front window        → 기존 사용자 창 (favorites://)
  새로 만든 창        → index 2
```

`front window`를 믿고 탭을 추가하면 **사용자 창에 탭이 들어간다.** 실제로 검증 중 그렇게 됐다. 창을 만든 뒤에는 반드시 첫 탭 URL로 다시 찾아야 한다.

**3. 첫 탭 URL로 창을 식별하는 방식이 동작한다.** 위 상황에서도 `URL of tab 1 of w`로 순회해 새 창을 정확히 찾았다.

**4. Safari의 시작 페이지 URL은 `favorites://`다.** 사용자의 기본 창이 이 값을 갖는다. 우리 URL과 겹칠 일이 없다.

**5. 어휘 차이**

| 동작 | Safari | Chrome |
|---|---|---|
| 창의 탭 목록 | `tabs of w` | `tabs of w` |
| 탭 URL | `URL of tab 1 of w` | `URL of tab 1 of w` |
| 새 창 + 첫 URL | `make new document with properties {URL:…}` | `make new window` 후 첫 탭 URL 설정 |
| 탭 추가 | `make new tab at end of tabs of w with properties {URL:…}` | 동일 |

**6. Chrome은 사용자가 작업 중이다.** 통합 검증은 Safari로만 한다. Chrome 경로는 단위 테스트(생성되는 스크립트 문자열)로만 덮는다.

---

## 파일 구조

| 파일 | 책임 |
|---|---|
| `Sources/RestageKit/URLNormalizer.swift` | URL 정규화 (순수) |
| `Sources/RestageKit/WorkspaceConfig.swift` | (수정) `BrowserItem`에 `window`, `slot` 추가 |
| `Sources/RestageKit/ScreenPlan.swift` | (수정) `PlannedItem`, `TabPlan` 추가, `UnsupportedItem` 제거 |
| `Sources/RestageKit/WorkspaceResolver.swift` | (수정) 브라우저 항목을 `TabPlan`으로 해석 |
| `Sources/RestageKitDarwin/AppleScriptRunner.swift` | `NSAppleScript` 실행과 권한 오류 판별 |
| `Sources/RestageKitDarwin/BrowserDialect.swift` | 브라우저별 AppleScript 생성 |
| `Sources/RestageKitDarwin/TabController.swift` | 창 식별, 탭 조회, 탭 추가 |
| `Sources/RestageKitDarwin/WorkspaceRunner.swift` | (수정) 브라우저 항목 처리 |

---

## Task 1: URLNormalizer

**Files:** create `Sources/RestageKit/URLNormalizer.swift`, `Tests/RestageKitTests/URLNormalizerTests.swift`.

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
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
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --filter URLNormalizerTests`
Expected: `cannot find 'URLNormalizer' in scope`

- [ ] **Step 3: 구현**

```swift
import Foundation

/// 브라우저가 돌려주는 URL과 config에 적힌 URL을 비교 가능한 형태로 맞춘다.
///
/// 브라우저는 `https://example.com`을 `https://example.com/`으로 돌려주고,
/// config에는 스킴 없이 `example.com`이라고 적을 수 있다. 이 차이를 흡수하지 않으면
/// 이미 열린 탭을 없는 것으로 보고 매번 중복해서 연다.
public enum URLNormalizer {
    private static let defaultScheme = "https://"

    public static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withScheme = hasScheme(trimmed) ? trimmed : defaultScheme + trimmed

        guard var components = URLComponents(string: withScheme) else { return withScheme }
        components.host = components.host?.lowercased()

        if components.path.hasSuffix("/"), components.path.count > 1 {
            components.path = String(components.path.dropLast())
        } else if components.path == "/", components.query == nil, components.fragment == nil {
            components.path = ""
        }

        return components.string ?? withScheme
    }

    private static func hasScheme(_ text: String) -> Bool {
        guard let range = text.range(of: "://") else { return false }
        let scheme = text[text.startIndex..<range.lowerBound]
        return !scheme.isEmpty && scheme.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `swift test --filter URLNormalizerTests`
Expected: 8개 PASS

기대값이 안 맞으면 기대값이 아니라 구현을 고친다. `trailingSlashOnRootWithQueryIsKept`가 까다로우므로 그것부터 확인한다.

- [ ] **Step 5: 커밋**

```bash
git add Sources/RestageKit/URLNormalizer.swift Tests/RestageKitTests/URLNormalizerTests.swift
git commit -m "feat: URL 정규화 추가"
```

---

## Task 2: 스키마와 해석기 확장

브라우저 항목이 더 이상 "미지원"이 아니므로 `UnsupportedItem`을 제거하고, 항목 순서를 유지하도록 `ScreenPlan`의 배열을 하나로 합친다.

3단계에서 실행 실패를 따로 모아 내보내 보고서가 선언 순서를 어긴 적이 있다. 배열을 둘로 나누면 같은 문제가 다시 생기므로 처음부터 하나로 둔다.

**Files:** modify `Sources/RestageKit/WorkspaceConfig.swift`, `Sources/RestageKit/ScreenPlan.swift`, `Sources/RestageKit/WorkspaceResolver.swift`; modify `Tests/RestageKitTests/WorkspaceResolverTests.swift`.

- [ ] **Step 1: 스키마 확장**

`WorkspaceConfig.swift`에서 `BrowserItem`을 교체하고 `BrowserWindowMode`를 추가한다.

```swift
public enum BrowserWindowMode: String, Decodable, Sendable {
    /// 워크스페이스 전용 창. config의 첫 URL을 첫 탭으로 가진 창을 찾는다.
    case separate
    /// 사용자 창을 빌려 쓴다. 맨 앞 창에 없는 탭만 추가한다.
    case shared
}

public struct BrowserItem: Sendable, Equatable {
    public let app: AppID
    public let window: BrowserWindowMode
    /// 없으면 창 크기와 위치를 건드리지 않는다.
    public let slot: Slot?
    public let tabs: [String]
}
```

`ItemConfig`의 `init(from:)`에서 browser 분기를 교체한다.

```swift
        case "browser":
            let tabs = try container.decodeIfPresent([String].self, forKey: .tabs) ?? []
            let window = try container.decodeIfPresent(
                BrowserWindowMode.self, forKey: .window) ?? .separate
            let slot = try container.decodeIfPresent(Slot.self, forKey: .slot)
            self = .browser(BrowserItem(app: app, window: window, slot: slot, tabs: tabs))
```

`Keys`에 `window`를 추가한다.

```swift
    private enum Keys: String, CodingKey {
        case type, app, slot, tabs, window
    }
```

- [ ] **Step 2: ScreenPlan 교체**

`ScreenPlan.swift`에서 `UnsupportedItem`을 삭제하고 다음을 추가한다.

```swift
/// 브라우저 항목의 해석 결과. tabs는 정규화되어 있다.
public struct TabPlan: Sendable, Equatable {
    public let app: AppID
    public let window: BrowserWindowMode
    public let slot: Slot?
    /// slot이 있을 때만 값이 있다.
    public let target: CGRect?
    public let tabs: [String]

    public init(app: AppID, window: BrowserWindowMode, slot: Slot?, target: CGRect?, tabs: [String]) {
        self.app = app
        self.window = window
        self.slot = slot
        self.target = target
        self.tabs = tabs
    }
}

/// 화면의 항목 하나. config 배열 순서를 그대로 유지한다.
public enum PlannedItem: Sendable, Equatable {
    case place(Placement)
    case tabs(TabPlan)

    public var app: AppID {
        switch self {
        case .place(let placement): return placement.app
        case .tabs(let plan): return plan.app
        }
    }
}
```

`ScreenPlan`을 교체한다.

```swift
public struct ScreenPlan: Sendable {
    public let id: String
    public let display: DisplayInfo
    public let mode: ScreenMode
    public let anchor: AppID?
    public let items: [PlannedItem]
}
```

- [ ] **Step 3: 해석기 교체**

`WorkspaceResolver.swift`의 `plan(for:on:)`을 교체한다.

```swift
    private static func plan(for screen: ScreenConfig, on display: DisplayInfo) -> ScreenPlan {
        let items = screen.items.map { item -> PlannedItem in
            switch item {
            case .app(let app):
                let target = SlotGeometry.frame(
                    for: app.slot, in: display.visibleFrame, primaryMaxY: display.primaryMaxY)
                return .place(Placement(app: app.app, slot: app.slot, target: target))
            case .browser(let browser):
                let target = browser.slot.map {
                    SlotGeometry.frame(
                        for: $0, in: display.visibleFrame, primaryMaxY: display.primaryMaxY)
                }
                return .tabs(TabPlan(
                    app: browser.app, window: browser.window, slot: browser.slot,
                    target: target, tabs: browser.tabs.map(URLNormalizer.normalize)))
            }
        }

        return ScreenPlan(
            id: screen.id, display: display, mode: screen.mode,
            anchor: screen.anchor, items: items)
    }
```

- [ ] **Step 4: 기존 테스트 갱신**

`WorkspaceResolverTests.swift`에서 `browserItemsBecomeUnsupported`를 다음으로 교체한다.

```swift
@Test func browserItemsBecomeTabPlans() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: web
        items:
          - {type: app, app: safari, slot: left-half}
          - type: browser
            app: chrome
            tabs: [example.com/a, https://example.com/b/]
    """, singleDisplay)
    #expect(result.screens[0].items.count == 2)
    guard case .tabs(let plan) = result.screens[0].items[1] else {
        Issue.record("tabs 항목이 아님")
        return
    }
    #expect(plan.app == AppID("chrome"))
    #expect(plan.window == .separate)
    #expect(plan.slot == nil)
    #expect(plan.target == nil)
    #expect(plan.tabs == ["https://example.com/a", "https://example.com/b"])
}

@Test func browserSlotProducesTarget() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: web
        items:
          - type: browser
            app: safari
            window: shared
            slot: right-half
            tabs: [https://example.com]
    """, singleDisplay)
    guard case .tabs(let plan) = result.screens[0].items[0] else {
        Issue.record("tabs 항목이 아님")
        return
    }
    #expect(plan.window == .shared)
    #expect(plan.slot == .rightHalf)
    #expect(plan.target
        == SlotGeometry.frame(for: .rightHalf, in: builtin.visibleFrame, primaryMaxY: 1117))
}
```

`preservesItemOrder`의 단언을 새 구조에 맞춘다.

```swift
    #expect(result.screens[0].items.map(\.app.rawValue) == ["safari", "iterm", "notion"])
```

`resolvesBuiltinToPrimary`, `resolvesExternalOne`, `externalTargetHasNegativeAXY`처럼 `placements[0]`를 쓰는 테스트는 다음 헬퍼를 파일 상단에 추가해 고친다.

```swift
private func firstPlacement(_ screen: ScreenPlan) -> Placement? {
    for item in screen.items {
        if case .place(let placement) = item { return placement }
    }
    return nil
}
```

그리고 `result.screens[0].placements[0].target`을 `firstPlacement(result.screens[0])!.target`으로 바꾼다.

- [ ] **Step 5: WorkspaceRunner 갱신**

`ScreenPlan.placements`와 `.unsupported`가 사라졌으므로 `runScreen`을 교체한다. 브라우저 항목 처리는 Task 6에서 채우고 지금은 `skipped`로 둔다.

```swift
    private func runScreen(_ screen: ScreenPlan) async -> [ItemOutcome] {
        var handles: [AppID: ProcessHandle] = [:]
        var launchFailures: [AppID: String] = [:]
        var outcomes: [ItemOutcome] = []

        for item in screen.items {
            guard handles[item.app] == nil, launchFailures[item.app] == nil else { continue }
            do {
                handles[item.app] = try await engine.launch(item.app)
            } catch {
                launchFailures[item.app] = String(describing: error)
            }
        }

        for item in screen.items {
            if let reason = launchFailures[item.app] {
                outcomes.append(ItemOutcome(
                    screenID: screen.id, app: item.app, status: .failed, detail: reason))
                continue
            }
            guard let handle = handles[item.app] else { continue }

            switch item {
            case .place(let placement):
                outcomes.append(await apply(placement, handle: handle, screen: screen))
            case .tabs(let plan):
                outcomes.append(ItemOutcome(
                    screenID: screen.id, app: plan.app, status: .skipped,
                    detail: "브라우저 탭 제어는 아직 구현되지 않았습니다"))
            }
        }

        if let anchor = screen.anchor, let handle = handles[anchor] {
            AXWindow.setApplicationFrontmost(pid: handle.pid)
        }

        return outcomes
    }
```

- [ ] **Step 6: 빌드와 테스트**

Run: `swift build` — 경고 0
Run: `swift test` — 기존 50개에 Task 1의 8개, 이번 1개가 더해져 59개 PASS

- [ ] **Step 7: 커밋**

```bash
git add Sources/RestageKit Sources/RestageKitDarwin/WorkspaceRunner.swift Tests/RestageKitTests
git commit -m "feat: 브라우저 항목 스키마 확장과 항목 순서 통합"
```

---

## Task 3: BrowserDialect

**Files:** create `Sources/RestageKitDarwin/BrowserDialect.swift`, `Tests/RestageKitDarwinTests/BrowserDialectTests.swift`.

- [ ] **Step 1: 실패하는 테스트 작성**

```swift
import Testing
import RestageKit
@testable import RestageKitDarwin

@Test func recognizesSupportedBrowsers() {
    #expect(BrowserDialect.forApp(AppID("safari")) != nil)
    #expect(BrowserDialect.forApp(AppID("chrome")) != nil)
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

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --filter BrowserDialectTests`
Expected: `cannot find 'BrowserDialect' in scope`

- [ ] **Step 3: 구현**

```swift
import Foundation
import RestageKit

/// 브라우저별 AppleScript 어휘 차이를 이 파일에만 가둔다.
/// 새 브라우저를 지원하려면 여기에 항목을 추가하면 된다.
struct BrowserDialect {
    let applicationName: String
    private let makesWindowWithURL: Bool

    private static let dialects: [String: BrowserDialect] = [
        "safari": BrowserDialect(applicationName: "Safari", makesWindowWithURL: true),
        "chrome": BrowserDialect(applicationName: "Google Chrome", makesWindowWithURL: false),
    ]

    static func forApp(_ app: AppID) -> BrowserDialect? {
        dialects[app.rawValue.lowercased()]
    }

    /// 창 id와 각 창의 탭 URL을 줄 단위로 돌려주는 스크립트.
    /// 출력 형식: `<windowID>\t<url>\t<url>...` 한 줄에 창 하나.
    func readWindowsScript() -> String {
        """
        tell application "\(applicationName)"
          set out to ""
          repeat with w in windows
            try
              set out to out & (id of w)
              repeat with t in tabs of w
                set out to out & tab & (URL of t)
              end repeat
              set out to out & linefeed
            end try
          end repeat
          return out
        end tell
        """
    }

    /// 새 창을 만들고 첫 URL을 연다.
    ///
    /// Safari는 `make new document`가 URL을 받고, Chrome은 창을 만든 뒤 첫 탭의
    /// URL을 설정해야 한다. 어느 쪽이든 만들어진 창이 맨 앞으로 온다는 보장이 없으므로
    /// 호출자는 첫 탭 URL로 창을 다시 찾아야 한다.
    func newWindowScript(url: String) -> String {
        if makesWindowWithURL {
            return """
            tell application "\(applicationName)"
              make new document with properties {URL:"\(escape(url))"}
            end tell
            """
        }
        return """
        tell application "\(applicationName)"
          set w to make new window
          set URL of active tab of w to "\(escape(url))"
        end tell
        """
    }

    func addTabScript(windowID: Int, url: String) -> String {
        """
        tell application "\(applicationName)"
          repeat with w in windows
            if (id of w) is \(windowID) then
              make new tab at end of tabs of w with properties {URL:"\(escape(url))"}
              exit repeat
            end if
          end repeat
        end tell
        """
    }

    func frontWindowIDScript() -> String {
        """
        tell application "\(applicationName)"
          if (count of windows) is 0 then return ""
          return (id of window 1) as string
        end tell
        """
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `swift test --filter BrowserDialectTests`
Expected: 5개 PASS

- [ ] **Step 5: 커밋**

```bash
git add Sources/RestageKitDarwin/BrowserDialect.swift Tests/RestageKitDarwinTests/BrowserDialectTests.swift
git commit -m "feat: 브라우저별 AppleScript 방언 추가"
```

---

## Task 4: AppleScriptRunner

**Files:** create `Sources/RestageKitDarwin/AppleScriptRunner.swift`.

- [ ] **Step 1: 구현**

```swift
import Foundation

enum AppleScriptError: Error, CustomStringConvertible {
    case permissionDenied(applicationName: String)
    case compilationFailed(String)
    case executionFailed(code: Int, message: String)

    var description: String {
        switch self {
        case .permissionDenied(let name):
            return """
                \(name) 자동화 권한이 없습니다. 시스템 설정 > 개인정보 보호 및 보안 > \
                자동화에서 restage가 \(name)을(를) 제어하도록 허용하세요
                """
        case .compilationFailed(let message):
            return "AppleScript 컴파일 실패: \(message)"
        case .executionFailed(let code, let message):
            return "AppleScript 실행 실패(\(code)): \(message)"
        }
    }
}

@MainActor
enum AppleScriptRunner {
    /// Apple Events 권한 거부. 사용자가 팝업에서 거부했거나 설정에서 껐을 때 온다.
    private static let permissionDeniedCode = -1743

    static func run(_ source: String, applicationName: String) throws -> String {
        guard let script = NSAppleScript(source: source) else {
            throw AppleScriptError.compilationFailed(source)
        }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        if let error {
            let code = error[NSAppleScript.errorNumber] as? Int ?? 0
            let message = error[NSAppleScript.errorMessage] as? String ?? "알 수 없는 오류"
            if code == permissionDeniedCode {
                throw AppleScriptError.permissionDenied(applicationName: applicationName)
            }
            throw AppleScriptError.executionFailed(code: code, message: message)
        }
        return result.stringValue ?? ""
    }
}
```

- [ ] **Step 2: 빌드**

Run: `swift build` — 경고 0

`NSAppleScript`가 `@MainActor`가 아니라는 경고가 나오면 `AppleScriptRunner`에 이미 붙어 있으므로 무시할 수 없다. 실제 경고 문구를 보고하고 멈춘다.

- [ ] **Step 3: 커밋**

```bash
git add Sources/RestageKitDarwin/AppleScriptRunner.swift
git commit -m "feat: AppleScript 실행과 권한 오류 판별 추가"
```

---

## Task 5: TabController

**Files:** create `Sources/RestageKitDarwin/TabController.swift`.

- [ ] **Step 1: 구현**

```swift
import Foundation
import RestageKit

struct BrowserWindow {
    let id: Int
    let tabURLs: [String]
}

/// 대상 창을 찾아 없는 탭만 추가한다. 아무것도 닫지 않는다.
@MainActor
enum TabController {
    /// 새 창을 만든 뒤 그것이 목록에 나타나기를 기다리는 시간.
    static let windowAppearTimeout: Duration = .seconds(5)

    struct Result {
        let openedCount: Int
        let windowID: Int
    }

    static func apply(_ plan: TabPlan, dialect: BrowserDialect) async throws -> Result {
        guard let first = plan.tabs.first else {
            throw AppleScriptError.executionFailed(code: 0, message: "탭이 비어 있습니다")
        }

        let windowID: Int
        switch plan.window {
        case .separate:
            windowID = try await resolveDedicatedWindow(firstURL: first, dialect: dialect)
        case .shared:
            windowID = try resolveFrontWindow(firstURL: first, dialect: dialect)
        }

        let existing = Set(try windows(dialect: dialect)
            .first { $0.id == windowID }?
            .tabURLs.map(URLNormalizer.normalize) ?? [])

        var opened = 0
        for url in plan.tabs where !existing.contains(url) {
            _ = try AppleScriptRunner.run(
                dialect.addTabScript(windowID: windowID, url: url),
                applicationName: dialect.applicationName)
            opened += 1
        }
        return Result(openedCount: opened, windowID: windowID)
    }

    /// config의 첫 URL을 첫 탭으로 가진 창을 찾는다. 없으면 만든다.
    ///
    /// 새로 만든 창은 맨 앞으로 온다는 보장이 없다. Safari에서 실제로 확인했다.
    /// 그래서 만든 뒤에도 `front window`가 아니라 첫 탭 URL로 다시 찾는다.
    private static func resolveDedicatedWindow(
        firstURL: String, dialect: BrowserDialect
    ) async throws -> Int {
        if let found = try findWindow(firstURL: firstURL, dialect: dialect) { return found }

        _ = try AppleScriptRunner.run(
            dialect.newWindowScript(url: firstURL),
            applicationName: dialect.applicationName)

        let appeared = await Polling.poll(timeout: windowAppearTimeout) {
            (try? findWindow(firstURL: firstURL, dialect: dialect)) ?? nil
        }
        guard let appeared else {
            throw AppleScriptError.executionFailed(
                code: 0, message: "새 창이 나타나지 않았습니다")
        }
        return appeared
    }

    private static func resolveFrontWindow(
        firstURL: String, dialect: BrowserDialect
    ) throws -> Int {
        let raw = try AppleScriptRunner.run(
            dialect.frontWindowIDScript(), applicationName: dialect.applicationName)
        if let id = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) { return id }

        _ = try AppleScriptRunner.run(
            dialect.newWindowScript(url: firstURL),
            applicationName: dialect.applicationName)
        let retry = try AppleScriptRunner.run(
            dialect.frontWindowIDScript(), applicationName: dialect.applicationName)
        guard let id = Int(retry.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw AppleScriptError.executionFailed(code: 0, message: "창을 찾을 수 없습니다")
        }
        return id
    }

    private static func findWindow(firstURL: String, dialect: BrowserDialect) throws -> Int? {
        try windows(dialect: dialect).first {
            guard let first = $0.tabURLs.first else { return false }
            return URLNormalizer.normalize(first) == firstURL
        }?.id
    }

    private static func windows(dialect: BrowserDialect) throws -> [BrowserWindow] {
        let raw = try AppleScriptRunner.run(
            dialect.readWindowsScript(), applicationName: dialect.applicationName)
        return raw.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard let id = Int(fields.first ?? "") else { return nil }
            return BrowserWindow(id: id, tabURLs: fields.dropFirst().map(String.init))
        }
    }
}
```

- [ ] **Step 2: 빌드**

Run: `swift build` — 경고 0

`Polling.poll`의 클로저가 throw를 삼키는 형태(`(try? ...) ?? nil`)인 이유는 폴링 중 일시적 오류로 전체를 실패시키지 않기 위해서다.

- [ ] **Step 3: 커밋**

```bash
git add Sources/RestageKitDarwin/TabController.swift
git commit -m "feat: 브라우저 창 식별과 탭 추가 추가"
```

---

## Task 6: WorkspaceRunner 연결

**Files:** modify `Sources/RestageKitDarwin/WorkspaceRunner.swift`.

- [ ] **Step 1: 브라우저 분기 교체**

Task 2에서 `skipped`로 두었던 자리를 채운다.

```swift
            case .tabs(let plan):
                outcomes.append(await applyTabs(plan, handle: handle, screen: screen))
```

그리고 다음 메서드를 추가한다.

```swift
    private func applyTabs(
        _ plan: TabPlan, handle: ProcessHandle, screen: ScreenPlan
    ) async -> ItemOutcome {
        guard let dialect = BrowserDialect.forApp(plan.app) else {
            return ItemOutcome(
                screenID: screen.id, app: plan.app, status: .skipped,
                detail: "지원하지 않는 브라우저입니다. 지원: safari, chrome")
        }

        do {
            _ = try await engine.waitForWindow(handle, timeout: Self.windowTimeout)
        } catch {
            let status: OutcomeStatus = CurrentState.windowCount(pid: handle.pid) > 0
                ? .unreachable : .failed
            return ItemOutcome(
                screenID: screen.id, app: plan.app, status: status,
                detail: String(describing: error))
        }

        let result: TabController.Result
        do {
            result = try await TabController.apply(plan, dialect: dialect)
        } catch {
            return ItemOutcome(
                screenID: screen.id, app: plan.app, status: .failed,
                detail: String(describing: error))
        }

        guard let target = plan.target else {
            return tabOutcome(result, plan: plan, screen: screen)
        }
        return await placeBrowserWindow(target, plan: plan, handle: handle,
                                        screen: screen, tabs: result)
    }

    /// 탭 작업을 한 창을 배치한다.
    ///
    /// AppleScript로 식별한 창과 AX 창을 직접 대응시킬 방법이 없으므로, 그 창을 맨 앞으로
    /// 올린 뒤 AX 창 목록의 첫 번째를 쓴다. AX 목록은 최근 활성 순이다.
    private func placeBrowserWindow(
        _ target: CGRect, plan: TabPlan, handle: ProcessHandle,
        screen: ScreenPlan, tabs: TabController.Result
    ) async -> ItemOutcome {
        AXWindow.setApplicationFrontmost(pid: handle.pid)
        guard let window = try? await engine.waitForWindow(handle, timeout: Self.windowTimeout),
              let slot = plan.slot else {
            return tabOutcome(tabs, plan: plan, screen: screen)
        }
        let result = await engine.place(window, slot: slot, display: screen.display)
        let placed = outcome(
            from: result,
            placement: Placement(app: plan.app, slot: slot, target: target),
            screen: screen)
        guard tabs.openedCount > 0 else { return placed }
        return ItemOutcome(
            screenID: placed.screenID, app: placed.app, status: placed.status,
            expected: placed.expected, actual: placed.actual,
            detail: "탭 \(tabs.openedCount)개 추가. \(placed.detail)")
    }

    private func tabOutcome(
        _ result: TabController.Result, plan: TabPlan, screen: ScreenPlan
    ) -> ItemOutcome {
        guard result.openedCount > 0 else {
            return ItemOutcome(
                screenID: screen.id, app: plan.app, status: .alreadySatisfied,
                detail: "탭 \(plan.tabs.count)개 모두 이미 열려 있음")
        }
        return ItemOutcome(
            screenID: screen.id, app: plan.app, status: .placed,
            detail: "탭 \(result.openedCount)개 추가")
    }
```

- [ ] **Step 2: 빌드와 테스트**

Run: `swift build` — 경고 0
Run: `swift test` — 64개 PASS

- [ ] **Step 3: 커밋**

```bash
git add Sources/RestageKitDarwin/WorkspaceRunner.swift
git commit -m "feat: 워크스페이스 루프에 브라우저 탭 처리 연결"
```

---

## Task 7: 통합 검증

**Safari로만 한다. Chrome은 사용자가 작업 중이며 유튜브가 열려 있다. 어떤 이유로도 Chrome을 대상으로 실행하지 않는다.**

**Files:** create `examples/research.yaml`, `docs/superpowers/plans/2026-08-23-browser-tabs-results.md`.

- [ ] **Step 1: 환경 준비**

```bash
osascript -e 'tell application "Rectangle" to quit' 2>/dev/null || true
caffeinate -d -i -t 1800 &
```

- [ ] **Step 2: config 작성과 첫 실행**

`examples/research.yaml`:

```yaml
workspace: research
screens:
  - id: web
    display: builtin
    mode: desktop
    items:
      - type: browser
        app: safari
        window: separate
        slot: right-half
        tabs:
          - https://example.com/
          - https://example.org/
```

Run: `.build/debug/restage open examples/research.yaml`

Expected: Safari에 새 창이 열리고 두 탭이 순서대로 생기며, 그 창이 우측 절반에 배치된다. 결과는 `placed`이고 note에 "탭 2개 추가"가 포함된다.

**사용자의 기존 Safari 창(시작 페이지)은 그대로 남아 있어야 한다.** 실행 후 Safari 창 목록을 확인한다.

```bash
osascript -e 'tell application "Safari" to get (count of windows)'
```

- [ ] **Step 3: 멱등성 확인**

Run: `.build/debug/restage open examples/research.yaml`

Expected: `alreadySatisfied`, note는 "탭 2개 모두 이미 열려 있음". 창이 늘지 않는다.

창이 늘어나면 창 식별이 실패한 것이다. 첫 탭 URL이 리다이렉트로 바뀌었는지 확인한다.

- [ ] **Step 4: 사용자 탭 보존 확인**

전용 창에 탭을 하나 수동으로 추가한 뒤 다시 실행한다.

```bash
osascript <<'OSA'
tell application "Safari"
  repeat with w in windows
    if (URL of tab 1 of w) starts with "https://example.com" then
      make new tab at end of tabs of w with properties {URL:"https://example.net"}
      exit repeat
    end if
  end repeat
end tell
OSA
.build/debug/restage open examples/research.yaml
```

Expected: `alreadySatisfied`이고, 수동으로 추가한 `example.net` 탭이 그대로 남아 있다. 이것이 비파괴 원칙의 확인이다.

- [ ] **Step 5: 탭 추가 확인**

config에 URL을 하나 더 넣고 실행한다.

```bash
cat > /tmp/restage-research2.yaml <<'YAML'
workspace: research
screens:
  - id: web
    display: builtin
    mode: desktop
    items:
      - type: browser
        app: safari
        window: separate
        slot: right-half
        tabs:
          - https://example.com/
          - https://example.org/
          - https://example.edu/
YAML
.build/debug/restage open /tmp/restage-research2.yaml
```

Expected: `placed`, note는 "탭 1개 추가". 새 URL만 열리고 기존 탭은 그대로다.

- [ ] **Step 6: 지원하지 않는 브라우저 확인**

```bash
cat > /tmp/restage-badbrowser.yaml <<'YAML'
workspace: bad
screens:
  - id: web
    display: builtin
    items:
      - type: browser
        app: notion
        tabs: [https://example.com]
YAML
.build/debug/restage open /tmp/restage-badbrowser.yaml
```

Expected: `skipped`, 사유는 "지원하지 않는 브라우저입니다. 지원: safari, chrome".

- [ ] **Step 7: 결과 기록과 커밋**

`docs/superpowers/plans/2026-08-23-browser-tabs-results.md`에 각 단계의 실제 출력, 조정한 값과 근거, 새로 발견한 제약을 적는다.

```bash
git add examples docs
git commit -m "docs: 브라우저 탭 제어 통합 검증 결과 기록"
```

---

## 완료 후 상태

- config에 선언한 URL이 브라우저 탭으로 열린다.
- 반복 실행해도 창이 늘지 않고 탭이 중복되지 않는다.
- 사용자가 따로 연 탭은 그대로 남는다.
- 브라우저 창도 slot으로 배치할 수 있다.

## 후속 사이클로 넘기는 것

- 워크스페이스 이름 레지스트리와 `ws open <name>`, `ws list` (5단계)
- 메뉴바 UI (6단계), 단축키 (7단계)
- Space 지정. yabai 선택 의존.
