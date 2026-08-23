# 워크스페이스 실행 루프 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 선언형 YAML 파일 하나로 워크스페이스를 복원한다. 1단계 엔진을 화면 단위 실행 루프로 조립하고 멀티 디스플레이를 지원한다.

**Architecture:** 파싱 → 해석 → 조정 → 보고의 4단 파이프라인. 앞 두 단계는 순수 함수라 실제 앱 없이 테스트한다. 조정 단계는 목표 상태와 현재 상태를 비교해 다른 것만 손대므로 멱등하다.

**Tech Stack:** Swift 6.3, SwiftPM, swift-testing(툴체인 내장), Yams 5.x, ApplicationServices, AppKit.

**Spec:** `docs/superpowers/specs/2026-08-23-workspace-runner-design.md`

**Branch:** `feat/workspace-runner` (PR #1의 `feat/window-placement-core` 위에 쌓임)

---

## 사전 확인 사항 (환경 검증 완료)

계획을 쓰기 전에 실제로 확인한 사실이다.

**1. Yams 5.4.0이 SwiftPM으로 해석되고 Swift 6 언어 모드에서 빌드된다.** `.package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")`.

**2. 다형 항목(`type: app` / `type: browser`) 디코딩이 커스텀 `init(from:)`으로 동작한다.** 아래 Task 1의 코드를 그대로 돌려 확인했다.

**3. Yams의 오류 메시지에 경로가 포함된다.** 잘못된 slot을 넣으면 다음이 나온다.

```
DecodingError.dataCorrupted: Data was corrupted. Path: screens[0].items[0].slot.
Debug description: Cannot initialize Slot from invalid String value bogus
```

이 경로 정보가 사용자 config 오류를 짚는 데 핵심이므로 버리지 말고 메시지에 실어야 한다.

**4. Task 1의 코드는 컴파일 검증을 마쳤다.** `ConfigError`, `WorkspaceConfig`, `DisplaySelector`, `ItemConfig`를 스크래치 패키지에 넣고 Task 1의 테스트 8개를 실제로 돌려 전부 통과함을 확인했다. 특히 다음 둘이 확인 대상이었다.

- 커스텀 `ConfigError`를 `init(from:)`에서 던지면 Yams를 통과해 그대로 전파된다. `DecodingError`로 감싸이지 않는다.
- `extension AppID: Decodable {}`만으로 `RawRepresentable` 합성이 동작한다. 1단계의 `CoreTypes.swift`를 수정할 필요가 없다.

**5. 1~2단계에서 확인한 플랫폼 제약이 이 설계의 전제다.**

- AX는 현재 Space의 창만 열거한다. `CGWindowListCopyWindowInfo(.optionAll)`은 Space와 무관하다.
- 전체화면은 편도다. AX로 넣을 수는 있어도 뺄 수 없다.
- AX 상수(`kAX*`)는 Swift 6 언어 모드에서 참조할 수 없다. 문자열 리터럴을 쓴다.
- MainActor 클로저를 받는 유틸리티는 그 자신도 `@MainActor`여야 한다.

---

## 파일 구조

| 파일 | 책임 |
|---|---|
| `Package.swift` | (수정) Yams 의존성 추가 |
| `Sources/RestageKit/WorkspaceConfig.swift` | YAML 스키마 타입과 디코딩 |
| `Sources/RestageKit/ConfigError.swift` | 파싱·검증 오류 |
| `Sources/RestageKit/ConfigLoader.swift` | 파일 읽기, 디코딩, 의미 검증 |
| `Sources/RestageKit/ScreenPlan.swift` | 해석된 목표 값 타입 |
| `Sources/RestageKit/WorkspaceResolver.swift` | config + 디스플레이 → 목표 (순수) |
| `Sources/RestageKit/ItemOutcome.swift` | 항목별 실행 결과 |
| `Sources/RestageKitDarwin/DisplayCatalog.swift` | 화면 열거와 정렬 |
| `Sources/RestageKitDarwin/CurrentState.swift` | Space 무관 현재 창 상태 조회 |
| `Sources/RestageKitDarwin/WorkspaceRunner.swift` | 조정 루프 |
| `Sources/RestageKitDarwin/WindowPlacer.swift` | (수정) 3단 적용 |
| `Sources/restage/OpenCommand.swift` | `restage open <경로>` |
| `Sources/restage/RunReport.swift` | 결과 표 |
| `Tests/RestageKitTests/WorkspaceConfigTests.swift` | 스키마 디코딩 |
| `Tests/RestageKitTests/ConfigLoaderTests.swift` | 검증 규칙 |
| `Tests/RestageKitTests/WorkspaceResolverTests.swift` | 목표 해석 |

---

## Task 1: Yams 의존성과 스키마 타입

**Files:**
- Modify: `Package.swift`
- Create: `Sources/RestageKit/ConfigError.swift`
- Create: `Sources/RestageKit/WorkspaceConfig.swift`
- Test: `Tests/RestageKitTests/WorkspaceConfigTests.swift`

`ConfigError`를 이 태스크에서 만드는 이유는 아래 스키마 코드가 이미 그것을 던지기 때문이다. 뒤 태스크로 미루면 이 태스크가 컴파일되지 않는다.

- [ ] **Step 1: Package.swift에 Yams 추가**

`RestageKit` 타겟에만 붙인다. `RestageKitDarwin`과 `restage`는 YAML을 몰라야 한다.

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "restage",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
    ],
    targets: [
        .target(name: "RestageKit", dependencies: [.product(name: "Yams", package: "Yams")]),
        .target(name: "RestageKitDarwin", dependencies: ["RestageKit"]),
        .executableTarget(name: "restage", dependencies: ["RestageKit", "RestageKitDarwin"]),
        .testTarget(name: "RestageKitTests", dependencies: ["RestageKit"]),
        .testTarget(name: "RestageKitDarwinTests", dependencies: ["RestageKitDarwin"]),
    ]
)
```

- [ ] **Step 2: 실패하는 테스트 작성**

`Tests/RestageKitTests/WorkspaceConfigTests.swift`:

```swift
import Testing
@testable import RestageKit

private let sample = """
workspace: dev
hotkey: "ctrl+alt+cmd+1"
screens:
  - id: code
    display: builtin
    mode: fullscreen
    anchor: cursor
    items:
      - {type: app, app: cursor, slot: left-half}
      - {type: app, app: iterm}
  - id: research
    items:
      - type: browser
        app: chrome
        tabs:
          - https://example.com/a
          - https://example.com/b
"""

@Test func decodesFullSchema() throws {
    let config = try WorkspaceConfig.decode(yaml: sample)
    #expect(config.workspace == "dev")
    #expect(config.hotkey == "ctrl+alt+cmd+1")
    #expect(config.screens.count == 2)
}

@Test func decodesAppItemsWithSlot() throws {
    let config = try WorkspaceConfig.decode(yaml: sample)
    let items = config.screens[0].items
    #expect(items.count == 2)
    guard case .app(let first) = items[0], case .app(let second) = items[1] else {
        Issue.record("app 항목이 아님")
        return
    }
    #expect(first.app == AppID("cursor"))
    #expect(first.slot == .leftHalf)
    #expect(second.app == AppID("iterm"))
    #expect(second.slot == .full)
}

@Test func decodesBrowserItemWithTabs() throws {
    let config = try WorkspaceConfig.decode(yaml: sample)
    guard case .browser(let browser) = config.screens[1].items[0] else {
        Issue.record("browser 항목이 아님")
        return
    }
    #expect(browser.app == AppID("chrome"))
    #expect(browser.tabs.count == 2)
}

@Test func appliesDefaults() throws {
    let config = try WorkspaceConfig.decode(yaml: sample)
    let research = config.screens[1]
    #expect(research.display == .any)
    #expect(research.mode == .desktop)
    #expect(research.anchor == nil)
}

@Test func parsesDisplaySelectors() throws {
    let yaml = """
    workspace: x
    screens:
      - id: a
        display: builtin
        items: [{type: app, app: safari}]
      - id: b
        display: external-1
        items: [{type: app, app: safari}]
      - id: c
        display: external-2
        items: [{type: app, app: safari}]
      - id: d
        display: any
        items: [{type: app, app: safari}]
    """
    let config = try WorkspaceConfig.decode(yaml: yaml)
    #expect(config.screens.map(\\.display) == [.builtin, .external(index: 1), .external(index: 2), .any])
}

@Test func rejectsInvalidSlot() {
    let yaml = """
    workspace: x
    screens:
      - id: a
        items: [{type: app, app: safari, slot: bogus}]
    """
    #expect(throws: ConfigError.self) { try WorkspaceConfig.decode(yaml: yaml) }
}

@Test func rejectsUnknownItemType() {
    let yaml = """
    workspace: x
    screens:
      - id: a
        items: [{type: widget, app: safari}]
    """
    #expect(throws: ConfigError.self) { try WorkspaceConfig.decode(yaml: yaml) }
}

@Test func rejectsInvalidDisplaySelector() {
    let yaml = """
    workspace: x
    screens:
      - id: a
        display: external-0
        items: [{type: app, app: safari}]
    """
    #expect(throws: ConfigError.self) { try WorkspaceConfig.decode(yaml: yaml) }
}

@Test func errorMessageKeepsPath() {
    let yaml = """
    workspace: x
    screens:
      - id: a
        items: [{type: app, app: safari, slot: bogus}]
    """
    do {
        _ = try WorkspaceConfig.decode(yaml: yaml)
        Issue.record("오류가 나지 않음")
    } catch {
        #expect("\\(error)".contains("slot"))
    }
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `swift test --filter WorkspaceConfigTests`
Expected: 컴파일 실패. `cannot find 'WorkspaceConfig' in scope`

- [ ] **Step 4: ConfigError 정의**

`Sources/RestageKit/ConfigError.swift`:

```swift
import Foundation

public enum ConfigError: Error, CustomStringConvertible {
    case fileNotFound(path: String)
    case unreadable(path: String, underlying: String)
    case malformed(detail: String)
    case unknownItemType(String)
    case invalidDisplaySelector(String)
    case emptyScreens
    case emptyItems(screenID: String)
    case duplicateScreenID(String)
    case anchorNotInItems(screenID: String, anchor: AppID)

    public var description: String {
        switch self {
        case .fileNotFound(let path):
            return "config 파일을 찾을 수 없습니다: \(path)"
        case .unreadable(let path, let underlying):
            return "config 파일을 읽을 수 없습니다: \(path) — \(underlying)"
        case .malformed(let detail):
            return "config 형식이 올바르지 않습니다. \(detail)"
        case .unknownItemType(let type):
            return "알 수 없는 항목 type입니다: \(type). 가능한 값: app, browser"
        case .invalidDisplaySelector(let raw):
            return "알 수 없는 display입니다: \(raw). 가능한 값: builtin, any, external-1 이상"
        case .emptyScreens:
            return "screens가 비어 있습니다. 화면을 하나 이상 선언하세요"
        case .emptyItems(let screenID):
            return "화면 '\(screenID)'의 items가 비어 있습니다"
        case .duplicateScreenID(let id):
            return "화면 id가 중복됩니다: \(id)"
        case .anchorNotInItems(let screenID, let anchor):
            return "화면 '\(screenID)'의 anchor '\(anchor.rawValue)'가 그 화면의 items에 없습니다"
        }
    }
}
```

`malformed`의 `detail`에는 Yams가 준 메시지를 그대로 싣는다. 거기에 `screens[0].items[0].slot` 같은 경로가 들어 있어 사용자가 어디를 고쳐야 할지 알 수 있다.

- [ ] **Step 5: 스키마 타입 구현**

`Sources/RestageKit/WorkspaceConfig.swift`:

```swift
import Foundation
import Yams

public struct WorkspaceConfig: Decodable, Sendable {
    public let workspace: String
    public let hotkey: String?
    public let screens: [ScreenConfig]

    public static func decode(yaml: String) throws -> WorkspaceConfig {
        do {
            return try YAMLDecoder().decode(WorkspaceConfig.self, from: yaml)
        } catch let error as ConfigError {
            throw error
        } catch {
            throw ConfigError.malformed(detail: String(describing: error))
        }
    }
}

public struct ScreenConfig: Decodable, Sendable {
    public let id: String
    public let display: DisplaySelector
    public let mode: ScreenMode
    public let anchor: AppID?
    public let items: [ItemConfig]

    private enum Keys: String, CodingKey {
        case id, display, mode, anchor, items
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        id = try container.decode(String.self, forKey: .id)
        display = try container.decodeIfPresent(DisplaySelector.self, forKey: .display) ?? .any
        mode = try container.decodeIfPresent(ScreenMode.self, forKey: .mode) ?? .desktop
        anchor = try container.decodeIfPresent(AppID.self, forKey: .anchor)
        items = try container.decode([ItemConfig].self, forKey: .items)
    }
}

public enum ScreenMode: String, Decodable, Sendable {
    case fullscreen
    case desktop
}

/// 어느 디스플레이에 배치할지. `external-N`의 N은 1부터 시작한다.
public enum DisplaySelector: Decodable, Sendable, Equatable {
    case builtin
    case external(index: Int)
    case any

    private static let externalPrefix = "external-"

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        switch raw {
        case "builtin": self = .builtin
        case "any": self = .any
        default:
            guard raw.hasPrefix(Self.externalPrefix),
                  let index = Int(raw.dropFirst(Self.externalPrefix.count)),
                  index >= 1 else {
                throw ConfigError.invalidDisplaySelector(raw)
            }
            self = .external(index: index)
        }
    }
}

public enum ItemConfig: Sendable, Equatable {
    case app(AppItem)
    case browser(BrowserItem)

    public var appID: AppID {
        switch self {
        case .app(let item): return item.app
        case .browser(let item): return item.app
        }
    }
}

public struct AppItem: Sendable, Equatable {
    public let app: AppID
    public let slot: Slot
}

public struct BrowserItem: Sendable, Equatable {
    public let app: AppID
    public let tabs: [String]
}

extension ItemConfig: Decodable {
    private enum Keys: String, CodingKey {
        case type, app, slot, tabs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        let type = try container.decode(String.self, forKey: .type)
        let app = try container.decode(AppID.self, forKey: .app)

        switch type {
        case "app":
            let slot = try container.decodeIfPresent(Slot.self, forKey: .slot) ?? .full
            self = .app(AppItem(app: app, slot: slot))
        case "browser":
            let tabs = try container.decodeIfPresent([String].self, forKey: .tabs) ?? []
            self = .browser(BrowserItem(app: app, tabs: tabs))
        default:
            throw ConfigError.unknownItemType(type)
        }
    }
}

extension AppID: Decodable {}
```

`AppID`는 `RawRepresentable`이고 `RawValue`가 `String`이므로 `Decodable` 적합만 선언하면 합성이 따라온다. 1단계에서 만든 `CoreTypes.swift`는 건드리지 않는다.

- [ ] **Step 6: 테스트 통과 확인**

Run: `swift test --filter WorkspaceConfigTests`
Expected: 9개 전부 PASS

Run: `swift build`
Expected: 경고 0

`rejectsInvalidSlot`이 실패하면 `Slot` 디코딩 오류가 `ConfigError`로 감싸이지 않은 것이다. `decode(yaml:)`의 catch 절을 확인한다.

- [ ] **Step 7: 커밋**

```bash
git add Package.swift Package.resolved Sources/RestageKit/ConfigError.swift Sources/RestageKit/WorkspaceConfig.swift Tests/RestageKitTests/WorkspaceConfigTests.swift
git commit -m "feat: YAML 워크스페이스 스키마 타입과 디코딩 추가"
```

---

## Task 2: ConfigLoader

**Files:**
- Create: `Sources/RestageKit/ConfigLoader.swift`
- Test: `Tests/RestageKitTests/ConfigLoaderTests.swift`

`ConfigError`는 Task 1에서 이미 정의했다. 여기서는 파일 읽기와 의미 검증을 채운다.

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/RestageKitTests/ConfigLoaderTests.swift`:

```swift
import Testing
import Foundation
@testable import RestageKit

private func load(_ yaml: String) throws -> WorkspaceConfig {
    try ConfigLoader.validated(WorkspaceConfig.decode(yaml: yaml))
}

@Test func acceptsValidConfig() throws {
    let config = try load("""
    workspace: dev
    screens:
      - id: code
        anchor: cursor
        items:
          - {type: app, app: cursor, slot: left-half}
          - {type: app, app: iterm, slot: right-half}
    """)
    #expect(config.screens.count == 1)
}

@Test func rejectsEmptyScreens() {
    #expect(throws: ConfigError.self) {
        try load("""
        workspace: dev
        screens: []
        """)
    }
}

@Test func rejectsEmptyItems() {
    #expect(throws: ConfigError.self) {
        try load("""
        workspace: dev
        screens:
          - id: code
            items: []
        """)
    }
}

@Test func rejectsDuplicateScreenID() {
    #expect(throws: ConfigError.self) {
        try load("""
        workspace: dev
        screens:
          - id: code
            items: [{type: app, app: safari}]
          - id: code
            items: [{type: app, app: iterm}]
        """)
    }
}

@Test func rejectsAnchorNotInItems() {
    #expect(throws: ConfigError.self) {
        try load("""
        workspace: dev
        screens:
          - id: code
            anchor: notion
            items: [{type: app, app: safari}]
        """)
    }
}

@Test func acceptsAnchorPointingToBrowserItem() throws {
    let config = try load("""
    workspace: dev
    screens:
      - id: web
        anchor: chrome
        items:
          - type: browser
            app: chrome
            tabs: [https://example.com]
    """)
    #expect(config.screens[0].anchor == AppID("chrome"))
}

@Test func reportsMissingFile() {
    #expect(throws: ConfigError.self) {
        try ConfigLoader.load(path: "/nonexistent/path/to/workspace.yaml")
    }
}

@Test func loadsFromFile() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("restage-config-test", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("workspace.yaml")
    try """
    workspace: dev
    screens:
      - id: code
        items: [{type: app, app: safari, slot: left-half}]
    """.write(to: file, atomically: true, encoding: .utf8)
    defer { try? FileManager.default.removeItem(at: directory) }

    let config = try ConfigLoader.load(path: file.path)
    #expect(config.workspace == "dev")
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --filter ConfigLoaderTests`
Expected: 컴파일 실패. `cannot find 'ConfigLoader' in scope`

- [ ] **Step 3: 구현**

`Sources/RestageKit/ConfigLoader.swift`:

```swift
import Foundation

public enum ConfigLoader {
    public static func load(path: String) throws -> WorkspaceConfig {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ConfigError.fileNotFound(path: path)
        }
        let text: String
        do {
            text = try String(contentsOfFile: path, encoding: .utf8)
        } catch {
            throw ConfigError.unreadable(path: path, underlying: error.localizedDescription)
        }
        return try validated(WorkspaceConfig.decode(yaml: text))
    }

    /// 스키마 디코딩이 잡지 못하는 의미 규칙을 검사한다.
    public static func validated(_ config: WorkspaceConfig) throws -> WorkspaceConfig {
        guard !config.screens.isEmpty else { throw ConfigError.emptyScreens }

        var seenIDs = Set<String>()
        for screen in config.screens {
            guard seenIDs.insert(screen.id).inserted else {
                throw ConfigError.duplicateScreenID(screen.id)
            }
            guard !screen.items.isEmpty else {
                throw ConfigError.emptyItems(screenID: screen.id)
            }
            if let anchor = screen.anchor {
                let declared = screen.items.map(\\.appID)
                guard declared.contains(anchor) else {
                    throw ConfigError.anchorNotInItems(screenID: screen.id, anchor: anchor)
                }
            }
        }
        return config
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `swift test --filter ConfigLoaderTests`
Expected: 8개 전부 PASS

Run: `swift build`
Expected: 경고 0

- [ ] **Step 5: 커밋**

```bash
git add Sources/RestageKit/ConfigLoader.swift Tests/RestageKitTests/ConfigLoaderTests.swift
git commit -m "feat: config 파일 로딩과 의미 검증 추가"
```

---

## Task 3: ScreenPlan과 WorkspaceResolver

이 태스크가 3단계의 핵심 순수 로직이다. config와 디스플레이 목록을 받아 구체적 목표 좌표를 계산한다.

**Files:**
- Create: `Sources/RestageKit/ScreenPlan.swift`
- Create: `Sources/RestageKit/WorkspaceResolver.swift`
- Test: `Tests/RestageKitTests/WorkspaceResolverTests.swift`

- [ ] **Step 1: 값 타입 정의**

`Sources/RestageKit/ScreenPlan.swift`:

```swift
import CoreGraphics

/// 사용 가능한 디스플레이 목록. externals는 프레임 원점 기준으로 정렬되어 있어야 한다.
public struct DisplayList: Sendable {
    public let primary: DisplayInfo
    public let externals: [DisplayInfo]

    public init(primary: DisplayInfo, externals: [DisplayInfo]) {
        self.primary = primary
        self.externals = externals
    }
}

/// 한 항목의 배치 목표. target은 AX 좌표계다.
public struct Placement: Sendable, Equatable {
    public let app: AppID
    public let slot: Slot
    public let target: CGRect

    public init(app: AppID, slot: Slot, target: CGRect) {
        self.app = app
        self.slot = slot
        self.target = target
    }
}

/// 이번 스코프에서 실행하지 않는 항목.
public struct UnsupportedItem: Sendable, Equatable {
    public let app: AppID
    public let reason: String

    public init(app: AppID, reason: String) {
        self.app = app
        self.reason = reason
    }
}

public struct ScreenPlan: Sendable {
    public let id: String
    public let display: DisplayInfo
    public let mode: ScreenMode
    public let anchor: AppID?
    public let placements: [Placement]
    public let unsupported: [UnsupportedItem]
}

public struct SkippedScreen: Sendable, Equatable {
    public let id: String
    public let reason: String
}

public struct ResolvedWorkspace: Sendable {
    public let workspace: String
    public let screens: [ScreenPlan]
    public let skipped: [SkippedScreen]
}
```

- [ ] **Step 2: 실패하는 테스트 작성**

`Tests/RestageKitTests/WorkspaceResolverTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import RestageKit

// 내장 1728x1117, 가용 영역 (0,57,1728,1027). 외장 2560x1440이 내장 위쪽에 배치.
private let builtin = DisplayInfo(
    visibleFrame: CGRect(x: 0, y: 57, width: 1728, height: 1027), primaryMaxY: 1117)
private let external = DisplayInfo(
    visibleFrame: CGRect(x: -419, y: 1117, width: 2560, height: 1440), primaryMaxY: 1117)

private let singleDisplay = DisplayList(primary: builtin, externals: [])
private let twoDisplays = DisplayList(primary: builtin, externals: [external])

private func resolve(_ yaml: String, _ displays: DisplayList) throws -> ResolvedWorkspace {
    try WorkspaceResolver.resolve(
        ConfigLoader.validated(WorkspaceConfig.decode(yaml: yaml)), displays: displays)
}

@Test func resolvesBuiltinToPrimary() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: code
        display: builtin
        items: [{type: app, app: safari, slot: left-half}]
    """, twoDisplays)
    #expect(result.screens.count == 1)
    #expect(result.screens[0].placements[0].target
        == SlotGeometry.frame(for: .leftHalf, in: builtin.visibleFrame, primaryMaxY: 1117))
}

@Test func resolvesAnyToPrimary() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: code
        display: any
        items: [{type: app, app: safari, slot: full}]
    """, twoDisplays)
    #expect(result.screens[0].display.visibleFrame == builtin.visibleFrame)
}

@Test func resolvesExternalOne() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: side
        display: external-1
        items: [{type: app, app: safari, slot: full}]
    """, twoDisplays)
    #expect(result.screens[0].display.visibleFrame == external.visibleFrame)
    #expect(result.screens[0].placements[0].target
        == SlotGeometry.frame(for: .full, in: external.visibleFrame, primaryMaxY: 1117))
}

@Test func skipsScreenWhenDisplayMissing() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: code
        display: builtin
        items: [{type: app, app: safari, slot: full}]
      - id: side
        display: external-1
        items: [{type: app, app: iterm, slot: full}]
    """, singleDisplay)
    #expect(result.screens.count == 1)
    #expect(result.screens[0].id == "code")
    #expect(result.skipped.count == 1)
    #expect(result.skipped[0].id == "side")
}

@Test func keepsRemainingScreensWhenOneIsSkipped() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: missing
        display: external-2
        items: [{type: app, app: safari, slot: full}]
      - id: code
        display: builtin
        items: [{type: app, app: iterm, slot: full}]
    """, twoDisplays)
    #expect(result.skipped.map(\\.id) == ["missing"])
    #expect(result.screens.map(\\.id) == ["code"])
}

@Test func browserItemsBecomeUnsupported() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: web
        items:
          - {type: app, app: safari, slot: left-half}
          - type: browser
            app: chrome
            tabs: [https://example.com]
    """, singleDisplay)
    #expect(result.screens[0].placements.count == 1)
    #expect(result.screens[0].unsupported.count == 1)
    #expect(result.screens[0].unsupported[0].app == AppID("chrome"))
}

@Test func preservesItemOrder() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: code
        items:
          - {type: app, app: safari, slot: left-half}
          - {type: app, app: iterm, slot: right-half}
          - {type: app, app: notion, slot: q1}
    """, singleDisplay)
    #expect(result.screens[0].placements.map(\\.app.rawValue) == ["safari", "iterm", "notion"])
}

@Test func carriesModeAndAnchor() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: code
        mode: fullscreen
        anchor: safari
        items: [{type: app, app: safari, slot: full}]
    """, singleDisplay)
    #expect(result.screens[0].mode == .fullscreen)
    #expect(result.screens[0].anchor == AppID("safari"))
}

@Test func allScreensSkippedYieldsEmptyPlan() throws {
    let result = try resolve("""
    workspace: dev
    screens:
      - id: side
        display: external-1
        items: [{type: app, app: safari, slot: full}]
    """, singleDisplay)
    #expect(result.screens.isEmpty)
    #expect(result.skipped.count == 1)
}
```

- [ ] **Step 3: 테스트 실패 확인**

Run: `swift test --filter WorkspaceResolverTests`
Expected: 컴파일 실패. `cannot find 'WorkspaceResolver' in scope`

- [ ] **Step 4: 구현**

`Sources/RestageKit/WorkspaceResolver.swift`:

```swift
import CoreGraphics

public enum WorkspaceResolver {
    /// config와 사용 가능한 디스플레이로 구체적 목표를 계산한다.
    /// 요청한 디스플레이가 없는 화면은 건너뛰고 사유를 남긴다. 나머지 화면은 그대로 진행한다.
    public static func resolve(
        _ config: WorkspaceConfig, displays: DisplayList
    ) -> ResolvedWorkspace {
        var plans: [ScreenPlan] = []
        var skipped: [SkippedScreen] = []

        for screen in config.screens {
            guard let display = display(for: screen.display, in: displays) else {
                skipped.append(SkippedScreen(
                    id: screen.id, reason: reason(forMissing: screen.display)))
                continue
            }
            plans.append(plan(for: screen, on: display))
        }

        return ResolvedWorkspace(workspace: config.workspace, screens: plans, skipped: skipped)
    }

    private static func plan(for screen: ScreenConfig, on display: DisplayInfo) -> ScreenPlan {
        var placements: [Placement] = []
        var unsupported: [UnsupportedItem] = []

        for item in screen.items {
            switch item {
            case .app(let app):
                let target = SlotGeometry.frame(
                    for: app.slot, in: display.visibleFrame, primaryMaxY: display.primaryMaxY)
                placements.append(Placement(app: app.app, slot: app.slot, target: target))
            case .browser(let browser):
                unsupported.append(UnsupportedItem(
                    app: browser.app, reason: "브라우저 탭 제어는 아직 구현되지 않았습니다"))
            }
        }

        return ScreenPlan(
            id: screen.id, display: display, mode: screen.mode,
            anchor: screen.anchor, placements: placements, unsupported: unsupported)
    }

    private static func display(
        for selector: DisplaySelector, in displays: DisplayList
    ) -> DisplayInfo? {
        switch selector {
        case .builtin, .any:
            return displays.primary
        case .external(let index):
            let position = index - 1
            guard displays.externals.indices.contains(position) else { return nil }
            return displays.externals[position]
        }
    }

    private static func reason(forMissing selector: DisplaySelector) -> String {
        switch selector {
        case .builtin, .any:
            return "주 디스플레이를 찾을 수 없습니다"
        case .external(let index):
            return "외장 디스플레이 \\(index)번이 연결되어 있지 않습니다"
        }
    }
}
```

`resolve`는 throw하지 않는다. 검증은 `ConfigLoader.validated`에서 끝났고, 여기서 실패할 수 있는 것은 "디스플레이 없음"뿐인데 그것은 오류가 아니라 건너뛸 사유이기 때문이다.

테스트의 `resolve` 헬퍼가 `try`를 쓰는 것은 앞단의 `decode`와 `validated` 때문이다.

- [ ] **Step 5: 테스트 통과 확인**

Run: `swift test --filter WorkspaceResolverTests`
Expected: 9개 전부 PASS

Run: `swift test`
Expected: 기존 21개 + Task 1의 9개 + Task 2의 8개 + 이번 9개 = 47개 전부 PASS

Run: `swift build`
Expected: 경고 0

- [ ] **Step 6: 커밋**

```bash
git add Sources/RestageKit/ScreenPlan.swift Sources/RestageKit/WorkspaceResolver.swift Tests/RestageKitTests/WorkspaceResolverTests.swift
git commit -m "feat: 워크스페이스 목표 상태 해석 추가"
```

---

## Task 4: ItemOutcome

**Files:**
- Create: `Sources/RestageKit/ItemOutcome.swift`

- [ ] **Step 1: 구현**

`Sources/RestageKit/ItemOutcome.swift`:

```swift
import CoreGraphics

public enum OutcomeStatus: String, Sendable {
    /// 배치했다.
    case placed
    /// 이미 목표 상태여서 건드리지 않았다. 멱등성의 핵심이다.
    case alreadySatisfied
    /// 앱이 막았다. 최소 크기, 크기 고정, 전체화면 미지원.
    case constrained
    /// 창이 다른 Space에 있어 접근할 수 없다.
    case unreachable
    /// 그 외 실패. 앱 미설치, 실행 실패, 창 미등장.
    case failed
    /// 미구현 기능.
    case skipped

    /// `constrained`를 성공으로 세는 이유는 고칠 수 없는 앱 동작이기 때문이다.
    /// `unreachable`을 실패로 세는 이유는 사용자가 해당 Space로 이동하면 해소되기 때문이다.
    public var isSuccess: Bool {
        switch self {
        case .placed, .alreadySatisfied, .constrained: return true
        case .unreachable, .failed, .skipped: return false
        }
    }
}

public struct ItemOutcome: Sendable {
    public let screenID: String
    /// 화면 단위로 건너뛴 경우에는 앱이 없다.
    public let app: AppID?
    public let status: OutcomeStatus
    public let expected: CGRect?
    public let actual: CGRect?
    public let detail: String

    public init(
        screenID: String, app: AppID?, status: OutcomeStatus,
        expected: CGRect? = nil, actual: CGRect? = nil, detail: String = ""
    ) {
        self.screenID = screenID
        self.app = app
        self.status = status
        self.expected = expected
        self.actual = actual
        self.detail = detail
    }
}
```

- [ ] **Step 2: 빌드**

Run: `swift build`
Expected: 경고 0

- [ ] **Step 3: 커밋**

```bash
git add Sources/RestageKit/ItemOutcome.swift
git commit -m "feat: 항목별 실행 결과 타입 추가"
```

---

## Task 5: DisplayCatalog

**Files:**
- Create: `Sources/RestageKitDarwin/DisplayCatalog.swift`

기존 `DisplayProvider`는 그대로 둔다. probe가 계속 쓴다.

- [ ] **Step 1: 구현**

`Sources/RestageKitDarwin/DisplayCatalog.swift`:

```swift
import AppKit
import RestageKit

@MainActor
public enum DisplayCatalog {
    /// 사용 가능한 디스플레이 목록.
    ///
    /// 외장 디스플레이는 프레임 원점 기준으로 정렬한다. `NSScreen.screens`의 배열 순서를
    /// 그대로 쓰면 재부팅이나 연결 순서에 따라 `external-1`이 가리키는 화면이 바뀐다.
    ///
    /// `primaryMaxY`는 모든 디스플레이에서 주 디스플레이의 값을 쓴다. AX 좌표계의 원점이
    /// 주 디스플레이 좌상단이므로, 외장 디스플레이의 좌표도 같은 기준으로 변환해야 한다.
    public static func current() -> DisplayList? {
        let screens = NSScreen.screens
        guard let primaryScreen = screens.first else { return nil }
        let primaryMaxY = primaryScreen.frame.maxY

        let primary = DisplayInfo(
            visibleFrame: primaryScreen.visibleFrame, primaryMaxY: primaryMaxY)

        let externals = screens.dropFirst()
            .sorted { lhs, rhs in
                if lhs.frame.minX != rhs.frame.minX { return lhs.frame.minX < rhs.frame.minX }
                return lhs.frame.minY < rhs.frame.minY
            }
            .map { DisplayInfo(visibleFrame: $0.visibleFrame, primaryMaxY: primaryMaxY) }

        return DisplayList(primary: primary, externals: externals)
    }
}
```

- [ ] **Step 2: 실제 값 확인**

`Sources/restage/main.swift`를 임시로 교체해 실행한다. Task 9에서 정식 진입점으로 다시 바꾼다.

```swift
import Foundation
import RestageKit
import RestageKitDarwin

guard AccessibilityPermission.isTrusted() else {
    print(AccessibilityPermission.onboardingMessage)
    exit(1)
}
guard let displays = DisplayCatalog.current() else {
    print("디스플레이를 찾을 수 없습니다")
    exit(1)
}
print("primary: visibleFrame=\(displays.primary.visibleFrame) primaryMaxY=\(displays.primary.primaryMaxY)")
for (index, external) in displays.externals.enumerated() {
    print("external-\(index + 1): visibleFrame=\(external.visibleFrame) primaryMaxY=\(external.primaryMaxY)")
}
```

Run: `swift run restage`

이 머신에는 디스플레이가 두 대 있다. 예상 출력은 다음과 같다.

```
primary: visibleFrame=(0.0, 57.0, 1728.0, 1027.0) primaryMaxY=1117.0
external-1: visibleFrame=(-419.0, 1117.0, 2560.0, 1440.0) primaryMaxY=1117.0
```

`external-1`의 `primaryMaxY`가 1117이 아니면 주 디스플레이 기준을 쓰지 않은 것이다.

- [ ] **Step 3: 커밋**

```bash
git add Sources/RestageKitDarwin/DisplayCatalog.swift Sources/restage/main.swift
git commit -m "feat: 멀티 디스플레이 열거와 정렬 추가"
```

---

## Task 6: WindowPlacer 3단 적용

**Files:**
- Modify: `Sources/RestageKitDarwin/WindowPlacer.swift`

- [ ] **Step 1: 적용 순서 교체**

`WindowPlacer`의 `apply` 함수를 다음으로 교체한다. 기존 주석도 함께 바꾼다.

```swift
    /// position → size → position 3단 적용.
    ///
    /// 크기부터 적용하면 창이 아직 원래 디스플레이에 있어 그 화면 경계로 clamp된다.
    /// 첫 position으로 목표 화면에 진입시키고, size를 적용한 뒤, size 적용 중 밀린
    /// position을 다시 맞춘다. 단일 디스플레이에서는 2단 적용과 결과가 같다.
    private static func apply(_ target: CGRect, to window: AXWindow) {
        window.setPosition(target.origin)
        window.setSize(target.size)
        window.setPosition(target.origin)
    }
```

- [ ] **Step 2: 빌드와 단위 테스트**

Run: `swift build`
Expected: 경고 0

Run: `swift test`
Expected: 기존 테스트 전부 PASS (좌표 계산은 영향받지 않는다)

- [ ] **Step 3: 1단계 회귀 확인**

3단 적용이 단일 디스플레이 결과를 바꾸지 않아야 한다. probe로 확인한다.

```bash
caffeinate -d -i -t 600 &
.build/debug/restage probe --app safari --slot left-half --warm-only
.build/debug/restage probe --app chrome --slot right-half --warm-only
.build/debug/restage probe --app notion --slot q1 --warm-only
```

Expected: 세 건 모두 `PASS`. 1단계 검증과 동일한 결과다.

`--warm-only`를 쓰는 이유는 콜드 스타트가 앱을 종료하기 때문이다. 회귀 확인에는 불필요하다.

`FAIL`이 나오면 3단 적용이 단일 디스플레이에서 부작용을 낸 것이다. 두 번째 `setPosition`이 크기를 되돌리는지 실측 좌표를 확인한다.

- [ ] **Step 4: 외장 디스플레이 배치 확인**

이 머신에는 외장 디스플레이가 있으므로 실제로 확인할 수 있다. 임시로 `main.swift`를 교체해 Safari를 외장 디스플레이 왼쪽 절반에 배치한다.

```swift
import Foundation
import RestageKit
import RestageKitDarwin

guard AccessibilityPermission.isTrusted(), !ScreenLock.isLocked() else {
    print("접근성 권한 또는 화면 잠금 확인 필요")
    exit(1)
}
guard let displays = DisplayCatalog.current(), let external = displays.externals.first else {
    print("외장 디스플레이가 없습니다")
    exit(1)
}

let engine = AXWindowEngine()
do {
    let handle = try await engine.launch(AppID("safari"))
    let window = try await engine.waitForWindow(handle, timeout: .seconds(15))
    let result = await engine.place(window, slot: .leftHalf, display: external)
    print("target=\(SlotGeometry.frame(for: .leftHalf, in: external.visibleFrame, primaryMaxY: external.primaryMaxY))")
    print("result=\(result)")
} catch {
    print("실패: \(error)")
    exit(1)
}
```

Run: `swift run restage`

Expected: Safari가 외장 디스플레이 왼쪽 절반으로 이동하고 `result`가 `.ok`다. 목표 좌표의 y는 음수여야 한다. 외장 디스플레이가 주 디스플레이 위쪽에 있어 AX 좌표계에서 음수 영역이기 때문이다.

`.failed`가 나오고 실측 좌표가 주 디스플레이 범위 안이면 3단 적용이 동작하지 않은 것이다.

- [ ] **Step 5: 커밋**

```bash
git add Sources/RestageKitDarwin/WindowPlacer.swift Sources/restage/main.swift
git commit -m "feat: 멀티 디스플레이용 3단 배치 적용"
```

---

## Task 7: CurrentState

목표 상태 판정을 담당한다. AX가 아니라 `CGWindowList`를 쓰는 것이 핵심이다.

**Files:**
- Create: `Sources/RestageKitDarwin/CurrentState.swift`

- [ ] **Step 1: 구현**

`Sources/RestageKitDarwin/CurrentState.swift`:

```swift
import AppKit
import CoreGraphics
import RestageKit

/// 현재 창 상태를 Space와 무관하게 조회한다.
///
/// AX를 쓰지 않는 이유는 AX가 현재 Space의 창만 열거하기 때문이다. 전체화면 앱은
/// 전용 Space로 옮겨져 AX에서 사라지므로, AX로 판정하면 이미 목표를 달성한 앱을
/// "창 없음"으로 오판한다. `CGWindowList`는 Space와 무관하게 창을 본다.
@MainActor
public enum CurrentState {
    public static let tolerance: CGFloat = 2

    /// 목표 사각형과 일치하는 창이 있는지.
    public static func isPlaced(pid: Int32, target: CGRect) -> Bool {
        windowRects(pid: pid).contains { matches($0, target) }
    }

    /// 해당 디스플레이를 가득 채우는 창이 있는지. 전체화면 달성 판정에 쓴다.
    ///
    /// 전체화면 창은 메뉴바 영역까지 덮으므로 `visibleFrame`이 아니라 디스플레이 전체
    /// 높이를 기준으로 삼는다. 앱마다 여백 처리가 달라 폭과 높이 각각 90% 이상이면
    /// 전체화면으로 본다.
    public static func isFullScreen(pid: Int32, on display: DisplayInfo) -> Bool {
        let width = display.visibleFrame.width
        let height = display.visibleFrame.height
        return windowRects(pid: pid).contains { rect in
            rect.width >= width * 0.9 && rect.height >= height * 0.9
        }
    }

    /// 해당 프로세스가 가진 창의 개수. 0이 아닌데 AX가 못 보면 다른 Space에 있다는 뜻이다.
    public static func windowCount(pid: Int32) -> Int {
        windowRects(pid: pid).count
    }

    private static func matches(_ rect: CGRect, _ target: CGRect) -> Bool {
        abs(rect.minX - target.minX) <= tolerance
            && abs(rect.minY - target.minY) <= tolerance
            && abs(rect.width - target.width) <= tolerance
            && abs(rect.height - target.height) <= tolerance
    }

    private static func windowRects(pid: Int32) -> [CGRect] {
        let list = CGWindowListCopyWindowInfo(
            [.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { window in
            guard window[kCGWindowOwnerPID as String] as? Int32 == pid,
                  window[kCGWindowLayer as String] as? Int == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
                  let width = bounds["Width"] as? Double, let height = bounds["Height"] as? Double,
                  height > 50 else { return nil }
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }
}
```

`CGWindowList`의 좌표는 AX와 같은 top-left 원점이므로 변환이 필요 없다. 1단계에서 Safari 창을 두 경로로 조회해 확인한 사실이다.

- [ ] **Step 2: 실제 값 확인**

임시 `main.swift`로 확인한다.

```swift
import Foundation
import RestageKit
import RestageKitDarwin

guard let displays = DisplayCatalog.current() else { exit(1) }
let target = SlotGeometry.frame(
    for: .leftHalf, in: displays.primary.visibleFrame, primaryMaxY: displays.primary.primaryMaxY)
print("target=\(target)")

for name in ["safari", "chrome", "notion"] {
    do {
        let bundleID = try AppRegistry.bundleID(for: AppID(name))
        guard let app = AppLauncher.runningApplication(bundleID: bundleID) else {
            print("\(name): 미실행"); continue
        }
        let pid = app.processIdentifier
        print("\(name): 창 \(CurrentState.windowCount(pid: pid))개 "
            + "isPlaced=\(CurrentState.isPlaced(pid: pid, target: target)) "
            + "isFullScreen=\(CurrentState.isFullScreen(pid: pid, on: displays.primary))")
    } catch {
        print("\(name): \(error)")
    }
}
```

Run: `swift run restage`

먼저 `.build/debug/restage probe --app safari --slot left-half --warm-only`로 Safari를 좌측 절반에 배치한 뒤 실행하면 Safari의 `isPlaced`가 `true`여야 한다.

- [ ] **Step 3: 커밋**

```bash
git add Sources/RestageKitDarwin/CurrentState.swift Sources/restage/main.swift
git commit -m "feat: Space 무관 현재 창 상태 조회 추가"
```

---

## Task 8: WorkspaceRunner

**Files:**
- Create: `Sources/RestageKitDarwin/WorkspaceRunner.swift`

- [ ] **Step 1: 구현**

`Sources/RestageKitDarwin/WorkspaceRunner.swift`:

```swift
import AppKit
import RestageKit

@MainActor
public struct WorkspaceRunner {
    public static let windowTimeout: Duration = .seconds(15)

    private let engine: AXWindowEngine

    public init(engine: AXWindowEngine = AXWindowEngine()) {
        self.engine = engine
    }

    public func run(_ resolved: ResolvedWorkspace) async -> [ItemOutcome] {
        var outcomes: [ItemOutcome] = []

        for screen in resolved.screens {
            outcomes.append(contentsOf: await runScreen(screen))
        }

        for skipped in resolved.skipped {
            outcomes.append(ItemOutcome(
                screenID: skipped.id, app: nil, status: .skipped, detail: skipped.reason))
        }

        await focusFirstAnchor(resolved)
        return outcomes
    }

    private func runScreen(_ screen: ScreenPlan) async -> [ItemOutcome] {
        var handles: [AppID: ProcessHandle] = [:]
        var outcomes: [ItemOutcome] = []

        for placement in screen.placements {
            do {
                handles[placement.app] = try await engine.launch(placement.app)
            } catch {
                outcomes.append(ItemOutcome(
                    screenID: screen.id, app: placement.app, status: .failed,
                    expected: placement.target, detail: String(describing: error)))
            }
        }

        for placement in screen.placements {
            guard let handle = handles[placement.app] else { continue }
            outcomes.append(await apply(placement, handle: handle, screen: screen))
        }

        for item in screen.unsupported {
            outcomes.append(ItemOutcome(
                screenID: screen.id, app: item.app, status: .skipped, detail: item.reason))
        }

        if let anchor = screen.anchor, let handle = handles[anchor] {
            AXWindow.setApplicationFrontmost(pid: handle.pid)
        }

        return outcomes
    }

    private func apply(
        _ placement: Placement, handle: ProcessHandle, screen: ScreenPlan
    ) async -> ItemOutcome {
        if isSatisfied(placement, handle: handle, screen: screen) {
            return ItemOutcome(
                screenID: screen.id, app: placement.app, status: .alreadySatisfied,
                expected: placement.target, detail: "이미 목표 상태")
        }

        let window: WindowHandle
        do {
            window = try await engine.waitForWindow(handle, timeout: Self.windowTimeout)
        } catch {
            let status: OutcomeStatus = CurrentState.windowCount(pid: handle.pid) > 0
                ? .unreachable : .failed
            return ItemOutcome(
                screenID: screen.id, app: placement.app, status: status,
                expected: placement.target, detail: String(describing: error))
        }

        let result = await engine.place(window, slot: placement.slot, display: screen.display)
        guard screen.mode == .fullscreen, result.isPass else {
            return outcome(from: result, placement: placement, screen: screen)
        }

        let fullScreenResult = await engine.fullscreen(window)
        return outcome(from: fullScreenResult, placement: placement, screen: screen)
    }

    /// 이미 목표 상태인지 판정한다. 이것이 멱등성의 핵심이다.
    ///
    /// 전체화면 목표는 AX로 판정할 수 없다. 전체화면 앱의 창은 다른 Space에 있어
    /// `AXWindows`가 비어 있기 때문이다. `CurrentState`가 `CGWindowList`로 판정한다.
    private func isSatisfied(
        _ placement: Placement, handle: ProcessHandle, screen: ScreenPlan
    ) -> Bool {
        if screen.mode == .fullscreen {
            return CurrentState.isFullScreen(pid: handle.pid, on: screen.display)
        }
        return CurrentState.isPlaced(pid: handle.pid, target: placement.target)
    }

    private func outcome(
        from result: PlacementResult, placement: Placement, screen: ScreenPlan
    ) -> ItemOutcome {
        switch result {
        case .ok(let actual, _, _, let warnings):
            return ItemOutcome(
                screenID: screen.id, app: placement.app, status: .placed,
                expected: placement.target, actual: actual,
                detail: warnings.joined(separator: "; "))
        case .constrained(let actual, let expected, let reason):
            return ItemOutcome(
                screenID: screen.id, app: placement.app, status: .constrained,
                expected: expected, actual: actual, detail: reason)
        case .failed(let expected, let actual, let reason):
            return ItemOutcome(
                screenID: screen.id, app: placement.app, status: .failed,
                expected: expected, actual: actual, detail: reason)
        }
    }

    /// 전체가 끝난 뒤 첫 화면의 anchor로 최종 포커스를 준다.
    private func focusFirstAnchor(_ resolved: ResolvedWorkspace) async {
        guard let screen = resolved.screens.first,
              let anchor = screen.anchor,
              let bundleID = try? AppRegistry.bundleID(for: anchor),
              let app = AppLauncher.runningApplication(bundleID: bundleID) else { return }
        AXWindow.setApplicationFrontmost(pid: app.processIdentifier)
    }
}
```

`AXWindow.setApplicationFrontmost`는 `RestageKitDarwin` 안에 있고 `WorkspaceRunner`도 같은 모듈이므로 `internal` 그대로 쓸 수 있다. 접근 수준을 올리지 않는다.

포커스에 `NSRunningApplication.activate()`를 쓰지 않는 이유는 1단계에서 확인했듯 호출하는 쪽이 GUI 앱이 아니면 macOS가 무시하기 때문이다. AX 경로만 동작한다.

- [ ] **Step 2: 빌드**

Run: `swift build`
Expected: 경고 0

- [ ] **Step 3: 커밋**

```bash
git add Sources/RestageKitDarwin
git commit -m "feat: 워크스페이스 조정 루프 추가"
```

---

## Task 9: OpenCommand와 RunReport

**Files:**
- Create: `Sources/restage/RunReport.swift`
- Create: `Sources/restage/OpenCommand.swift`
- Modify: `Sources/restage/main.swift`

- [ ] **Step 1: RunReport 구현**

`Sources/restage/RunReport.swift`:

```swift
import CoreGraphics
import Foundation
import RestageKit

enum RunReport {
    static func render(workspace: String, outcomes: [ItemOutcome]) -> String {
        var lines: [String] = ["워크스페이스: \(workspace)", ""]
        lines.append(
            pad("SCREEN", 12) + pad("APP", 12) + pad("RESULT", 18)
            + pad("EXPECTED", 23) + pad("ACTUAL", 23) + "NOTE")
        lines.append(String(repeating: "-", count: 110))

        for outcome in outcomes {
            lines.append(
                pad(outcome.screenID, 12) + pad(outcome.app.rawValue, 12)
                + pad(outcome.status.rawValue, 18)
                + pad(outcome.expected.map(format) ?? "-", 23)
                + pad(outcome.actual.map(format) ?? "-", 23)
                + outcome.detail)
        }

        lines.append("")
        lines.append(summary(outcomes))
        return lines.joined(separator: "\n")
    }

    static func summary(_ outcomes: [ItemOutcome]) -> String {
        let counts = Dictionary(grouping: outcomes, by: \.status.rawValue).mapValues(\.count)
        let order = ["placed", "alreadySatisfied", "constrained", "unreachable", "failed", "skipped"]
        let parts = order.compactMap { key -> String? in
            guard let count = counts[key] else { return nil }
            return "\(key) \(count)"
        }
        let failures = outcomes.filter { !$0.status.isSuccess }
        let verdict = failures.isEmpty ? "완료" : "완료 (실패 \(failures.count)건)"
        return "\(parts.joined(separator: " / "))  총 \(outcomes.count)건 — \(verdict)"
    }

    static func hasFailure(_ outcomes: [ItemOutcome]) -> Bool {
        outcomes.contains { !$0.status.isSuccess }
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }

    private static func format(_ rect: CGRect) -> String {
        String(format: "%.0f,%.0f %.0fx%.0f", rect.minX, rect.minY, rect.width, rect.height)
    }
}
```

- [ ] **Step 2: OpenCommand 구현**

`Sources/restage/OpenCommand.swift`:

```swift
import Foundation
import RestageKit
import RestageKitDarwin

@MainActor
enum OpenCommand {
    static func run(path: String) async -> Int32 {
        guard AccessibilityPermission.isTrusted() else {
            print(AccessibilityPermission.onboardingMessage)
            return 1
        }
        guard !ScreenLock.isLocked() else {
            print(ScreenLock.message)
            return 1
        }
        guard let displays = DisplayCatalog.current() else {
            print("디스플레이 정보를 조회할 수 없습니다")
            return 1
        }

        let config: WorkspaceConfig
        do {
            config = try ConfigLoader.load(path: path)
        } catch {
            print(error)
            return 2
        }

        let resolved = WorkspaceResolver.resolve(config, displays: displays)
        let outcomes = await WorkspaceRunner().run(resolved)

        print(RunReport.render(workspace: resolved.workspace, outcomes: outcomes))
        return RunReport.hasFailure(outcomes) ? 1 : 0
    }
}
```

config 오류는 종료 코드 2, 실행 중 실패는 1로 구분한다. 전자는 사용자가 파일을 고쳐야 하고 후자는 환경 문제다.

- [ ] **Step 3: main.swift 교체**

`Sources/restage/main.swift`:

```swift
import Foundation
import RestageKitDarwin

let usage = """
restage — 워크스페이스 복원 도구

사용법:
  restage open <config.yaml>
  restage probe [--slot <slot>] [--app <name>] [--fullscreen] [--warm-only]

open 옵션:
  <config.yaml>   워크스페이스 config 파일 경로

probe 옵션:
  --slot <slot>   배치할 위치. 기본값 left-half
  --app <name>    단일 앱만 검증. 기본값은 표본 전부
  --fullscreen    배치 후 전체화면 전환까지 검증
  --warm-only     콜드 스타트를 건너뛴다. 앱을 종료하지 않고 현재 상태 그대로 검증
"""

let arguments = Array(CommandLine.arguments.dropFirst())

guard let command = arguments.first else {
    print(usage)
    exit(2)
}

switch command {
case "open":
    guard arguments.count >= 2 else {
        print("open 뒤에 config 파일 경로가 필요합니다")
        print("")
        print(usage)
        exit(2)
    }
    let code = await OpenCommand.run(path: arguments[1])
    exit(code)
case "probe":
    do {
        let options = try ProbeOptions.parse(Array(arguments.dropFirst()))
        let code = await ProbeCommand.run(options)
        exit(code)
    } catch {
        print(error)
        print("")
        print(usage)
        exit(2)
    }
default:
    print("알 수 없는 명령: \(command)")
    print("")
    print(usage)
    exit(2)
}
```

- [ ] **Step 4: 인자 처리 확인**

Run: `swift build`
Expected: 경고 0

Run: `.build/debug/restage`
Expected: usage 출력, 종료 코드 2

Run: `.build/debug/restage open`
Expected: "open 뒤에 config 파일 경로가 필요합니다", 종료 코드 2

Run: `.build/debug/restage open /nonexistent.yaml`
Expected: "config 파일을 찾을 수 없습니다: /nonexistent.yaml", 종료 코드 2

- [ ] **Step 5: 커밋**

```bash
git add Sources/restage
git commit -m "feat: restage open 명령과 결과 표 추가"
```

---

## Task 10: 통합 검증 게이트

코드를 쓰는 태스크가 아니라 실제로 동작하게 만드는 태스크다.

**Files:**
- Create: `examples/dev.yaml`
- Create: `examples/two-screens.yaml`
- Create: `docs/superpowers/plans/2026-08-23-workspace-runner-results.md`

**이 태스크는 사용자의 앱을 실행하고 창을 옮긴다.** 전체화면은 되돌릴 수 없으므로 `mode: desktop` 위주로 구성하고 전체화면은 마지막에 한 번만 확인한다.

- [ ] **Step 1: 검증 환경 준비**

```bash
osascript -e 'tell application "Rectangle" to quit' 2>/dev/null || true
caffeinate -d -i -t 1800 &
```

Rectangle이 실행 중이면 배치 직후 창을 다시 잡아 측정이 오염된다. 화면 잠금은 AX 조회를 전부 실패시킨다. 둘 다 1~2단계에서 실제로 겪은 문제다.

- [ ] **Step 2: 단일 화면 config 작성과 실행**

`examples/dev.yaml`:

```yaml
workspace: dev
screens:
  - id: main
    display: builtin
    mode: desktop
    anchor: safari
    items:
      - {type: app, app: safari, slot: left-half}
      - {type: app, app: notion, slot: right-half}
```

Run: `.build/debug/restage open examples/dev.yaml`

Expected: Safari가 좌측 절반, Notion이 우측 절반에 배치되고 두 항목 모두 `placed`. 마지막에 Safari가 최전면.

- [ ] **Step 3: 멱등성 확인**

같은 명령을 한 번 더 실행한다.

Run: `.build/debug/restage open examples/dev.yaml`

Expected: 두 항목 모두 `alreadySatisfied`. 창이 움직이지 않는다.

`placed`가 다시 나오면 `CurrentState.isPlaced`의 tolerance 판정이 어긋난 것이다. 실측 좌표와 목표 좌표를 비교한다. 1단계에서 관측했듯 일부 앱은 요청한 높이보다 1pt 작게 안착하므로, tolerance 2pt 안에 들어와야 한다.

- [ ] **Step 4: 2화면 config 작성과 실행**

`examples/two-screens.yaml`:

```yaml
workspace: split
screens:
  - id: main
    display: builtin
    mode: desktop
    anchor: safari
    items:
      - {type: app, app: safari, slot: left-half}
      - {type: app, app: notion, slot: right-half}

  - id: side
    display: external-1
    mode: desktop
    items:
      - {type: app, app: chrome, slot: full}
```

Run: `.build/debug/restage open examples/two-screens.yaml`

Expected: Chrome이 외장 디스플레이 전체를 채운다. 세 항목 모두 `placed`.

Chrome의 실측 좌표 y가 음수여야 한다. 외장 디스플레이가 주 디스플레이 위쪽에 있기 때문이다. 양수가 나오면 `DisplayCatalog`가 `primaryMaxY`를 잘못 계산한 것이다.

- [ ] **Step 5: 부분 실패 확인**

존재하지 않는 앱과 연결되지 않은 디스플레이를 포함한 config로 나머지가 완료되는지 확인한다. 임시 파일을 쓰고 커밋하지 않는다.

```bash
cat > /tmp/restage-partial.yaml <<'YAML'
workspace: partial
screens:
  - id: main
    display: builtin
    items:
      - {type: app, app: safari, slot: left-half}
      - {type: app, app: nonexistent-app, slot: right-half}

  - id: missing
    display: external-9
    items:
      - {type: app, app: notion, slot: full}
YAML
.build/debug/restage open /tmp/restage-partial.yaml
```

Expected:

- Safari는 `placed`
- `nonexistent-app`은 `failed`, 사유는 "레지스트리에 없는 앱입니다"
- `missing` 화면은 `skipped`, 사유는 "외장 디스플레이 9번이 연결되어 있지 않습니다"
- 종료 코드 1

한 항목의 실패가 나머지를 막지 않는 것이 이 단계의 확인 대상이다.

- [ ] **Step 6: 브라우저 항목 확인**

```bash
cat > /tmp/restage-browser.yaml <<'YAML'
workspace: browser
screens:
  - id: web
    display: builtin
    items:
      - {type: app, app: safari, slot: left-half}
      - type: browser
        app: chrome
        tabs:
          - https://example.com
YAML
.build/debug/restage open /tmp/restage-browser.yaml
```

Expected: Safari는 `placed`, Chrome 항목은 `skipped`이며 사유가 "브라우저 탭 제어는 아직 구현되지 않았습니다".

조용히 무시되지 않고 결과에 드러나는 것이 확인 대상이다.

- [ ] **Step 7: 전체화면 확인 (1회만)**

```bash
cat > /tmp/restage-fs.yaml <<'YAML'
workspace: fs
screens:
  - id: focus
    display: builtin
    mode: fullscreen
    items:
      - {type: app, app: safari, slot: full}
YAML
.build/debug/restage open /tmp/restage-fs.yaml
```

Expected: Safari가 전체화면이 되고 `placed`.

이어서 같은 명령을 한 번 더 실행한다.

Expected: `alreadySatisfied`. 이것이 전체화면 멱등성의 확인이다. AX로는 전체화면 앱의 창을 볼 수 없으므로, `CurrentState.isFullScreen`이 `CGWindowList`로 올바르게 판정해야만 통과한다.

**이 단계는 Safari를 전체화면에 남긴다.** 확인 후 `ctrl+cmd+F`로 직접 해제한다. AX로는 해제할 수 없다.

- [ ] **Step 8: 결과 기록**

`docs/superpowers/plans/2026-08-23-workspace-runner-results.md`에 다음을 적는다.

- 각 단계의 실제 출력 표
- 멱등성 확인 결과 (2회차가 전부 `alreadySatisfied`인지)
- 외장 디스플레이 배치의 실측 좌표
- 조정한 상수와 그 근거
- 새로 발견한 제약

- [ ] **Step 9: 커밋**

```bash
git add examples docs
git commit -m "docs: 워크스페이스 실행 루프 통합 검증 결과 기록"
```

---

## 완료 후 상태

- `restage open <config.yaml>`으로 워크스페이스를 복원할 수 있다.
- 같은 명령을 반복해도 결과가 같고 창이 불필요하게 움직이지 않는다.
- 멀티 디스플레이가 동작한다.
- 순수 로직(파싱, 검증, 해석)이 단위 테스트로 덮여 있다.

## 후속 사이클로 넘기는 것

- 브라우저 탭 제어 (4단계). Apple Events 권한이 대상 앱별로 필요하다.
- 워크스페이스 이름 레지스트리와 `ws open <name>`, `ws list` (5단계). config 파일 위치 규약도 그때 정한다.
- 메뉴바 UI (6단계), 단축키 (7단계).
- Space 지정. yabai 선택 의존.
