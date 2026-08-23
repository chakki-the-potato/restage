# 창 배치 엔진 코어 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 지정한 앱을 지정한 slot에 배치하고 네이티브 전체화면으로 전환하는 엔진 코어를 만들고, 검증 표본 10종에서 콜드/웜 스타트 모두 통과시킨다.

**Architecture:** Swift Package 3계층. `RestageKit`은 OS를 모르는 인터페이스와 순수 좌표 계산, `RestageKitDarwin`은 AX/NSWorkspace 구현, `restage`는 probe 하네스를 가진 실행 진입점. 검증은 XCTest가 아니라 배포 바이너리 자신의 `probe` 서브커맨드로 수행한다.

**Tech Stack:** Swift 6.3, SwiftPM, swift-testing(툴체인 내장), ApplicationServices(AXUIElement), AppKit(NSWorkspace/NSScreen). 외부 패키지 의존성 없음.

**Spec:** `docs/superpowers/specs/2026-08-23-window-placement-core-design.md`

---

## 사전 확인 사항 (환경 검증 완료)

이 계획을 쓰기 전에 실제로 확인한 사실이다. 구현 중 헤매지 않도록 기록한다.

**1. swift-testing은 외부 의존성 없이 동작한다.** `// swift-tools-version:6.0` + `import Testing` + `@Test` / `#expect` 조합이 `swift test`로 통과함을 확인했다. XCTest를 쓸 이유가 없다.

**2. Swift 6 strict concurrency에서 AX 상수는 쓸 수 없다.** `kAXTrustedCheckOptionPrompt`, `kAXPositionAttribute` 등은 C 헤더에서 `extern CFStringRef`로 선언되어 Swift에 전역 `var`로 임포트된다. Swift 6 언어 모드에서 이를 참조하면 다음 **에러**가 난다.

```
error: reference to var 'kAXTrustedCheckOptionPrompt' is not concurrency-safe
       because it involves shared mutable state
```

따라서 **모든 AX 속성 이름은 문자열 리터럴로 쓴다.** 이 계획의 `AXAttributes` 열거형이 그 리터럴을 한곳에 모으는 역할을 한다.

**3. `AXValueGetValue`를 제네릭 `inout T`로 감싸면 안 된다.** 다음 경고가 난다.

```
warning: forming 'UnsafeMutableRawPointer' to a variable of type 'T';
         this is likely incorrect because 'T' may contain an object reference
```

`CGPoint`, `CGSize` 각각에 대해 구체 타입 접근자를 따로 만든다.

**4. 접근성 권한이 현재 미승인이다.** 확인 시점에 `AXIsProcessTrustedWithOptions`가 `false`를 반환했고, `AXUIElementCopyAttributeValue`가 `-25211`(`kAXErrorAPIDisabled`)을 반환했다. Task 1에서 먼저 해결해야 그 뒤 모든 검증이 의미를 갖는다.

**5. 권한은 실행을 시작한 앱에 귀속된다.** SwiftPM으로 빌드한 unsigned 바이너리는 재빌드마다 코드 서명 해시가 바뀌므로 개별 승인이 유지되지 않는다. 대신 터미널에서 실행하면 그 **터미널 앱**의 승인을 상속한다. 개발 중에는 iTerm에 접근성 권한을 주고 iTerm에서 `swift run`하는 것을 기본 경로로 삼는다.

**6. `WindowRef`라는 이름은 쓸 수 없다.** Carbon(HIToolbox)이 같은 이름의 타입을 정의하고 있어, `ApplicationServices`를 import한 파일에서 다음 에러가 난다.

```
error: 'WindowRef' is ambiguous for type lookup in this context
```

이 계획은 `WindowHandle`이라는 이름을 쓴다.

**7. `Polling`은 `@MainActor`여야 한다.** 호출자가 전부 MainActor 격리 타입이므로 비격리 유틸리티에 클로저를 넘기면 다음 에러가 난다.

```
error: sending value of non-Sendable type '() -> CGRect?' risks causing data races
```

**8. 이 계획의 코드는 컴파일 검증을 마쳤다.** Task 1~12, 14의 모든 Swift 코드를 스크래치 패키지에 넣고 `swift build`로 **에러 0, 경고 0**을 확인했다. Task 2의 테스트 11개도 실제로 실행해 전부 통과함을 확인했다. 따라서 위 5~7번 이외의 컴파일 문제가 나오면 계획을 그대로 옮기지 않은 것이다.

---

## 파일 구조

| 파일 | 책임 |
|---|---|
| `Package.swift` | 타겟 정의, 배포 타겟 macOS 13 |
| `Sources/RestageKit/Slot.swift` | slot 열거형 |
| `Sources/RestageKit/SlotGeometry.swift` | slot → 좌표 계산 및 좌표계 변환 (순수 함수) |
| `Sources/RestageKit/CoreTypes.swift` | `AppID`, `ProcessHandle`, `DisplayInfo`, `WindowHandle` |
| `Sources/RestageKit/PlacementResult.swift` | 배치 결과 값 타입 |
| `Sources/RestageKit/EngineError.swift` | 엔진 오류 타입 |
| `Sources/RestageKit/WindowEngine.swift` | 엔진 프로토콜 |
| `Sources/RestageKitDarwin/AXAttributes.swift` | AX 속성 이름 문자열 상수 |
| `Sources/RestageKitDarwin/AXWindow.swift` | `AXUIElement` 속성 접근 래퍼 |
| `Sources/RestageKitDarwin/AccessibilityPermission.swift` | 권한 확인과 온보딩 안내 |
| `Sources/RestageKitDarwin/AppRegistry.swift` | 논리 앱 이름 → bundle ID |
| `Sources/RestageKitDarwin/Polling.swift` | 공용 폴링 유틸리티 |
| `Sources/RestageKitDarwin/AppLauncher.swift` | 앱 실행과 기존 프로세스 탐지 |
| `Sources/RestageKitDarwin/DisplayProvider.swift` | `NSScreen` → `DisplayInfo` |
| `Sources/RestageKitDarwin/WindowWaiter.swift` | 창 등장 대기 폴링 |
| `Sources/RestageKitDarwin/WindowPlacer.swift` | 배치 수렴 루프 |
| `Sources/RestageKitDarwin/FullScreenController.swift` | 전체화면 진입/해제 |
| `Sources/RestageKitDarwin/AXWindowEngine.swift` | 위 컴포넌트 조립 |
| `Sources/restage/ProbeReport.swift` | 결과 표 조립 및 출력 |
| `Sources/restage/ProbeCommand.swift` | probe 실행 흐름과 인자 파싱 |
| `Sources/restage/main.swift` | 진입점 |
| `Tests/RestageKitTests/SlotGeometryTests.swift` | 좌표 계산 검증 |
| `Tests/RestageKitDarwinTests/AppRegistryTests.swift` | bundle ID 매핑 검증 |

---

## Task 1: 패키지 스캐폴딩과 접근성 권한 확보

**Files:**
- Create: `Package.swift`
- Create: `Sources/RestageKit/Placeholder.swift`
- Create: `Sources/RestageKitDarwin/AccessibilityPermission.swift`
- Create: `Sources/restage/main.swift`

- [ ] **Step 1: Package.swift 작성**

```swift
// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "restage",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "RestageKit"),
        .target(name: "RestageKitDarwin", dependencies: ["RestageKit"]),
        .executableTarget(name: "restage", dependencies: ["RestageKit", "RestageKitDarwin"]),
        .testTarget(name: "RestageKitTests", dependencies: ["RestageKit"]),
        .testTarget(name: "RestageKitDarwinTests", dependencies: ["RestageKitDarwin"]),
    ]
)
```

- [ ] **Step 2: 빈 타겟이 빌드되도록 최소 파일 추가**

`Sources/RestageKit/Placeholder.swift`:

```swift
public enum RestageKit {
    public static let version = "0.1.0"
}
```

- [ ] **Step 3: AccessibilityPermission 구현**

`Sources/RestageKitDarwin/AccessibilityPermission.swift`:

```swift
import ApplicationServices

public enum AccessibilityPermission {
    public static let settingsDeepLink =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    public static func isTrusted() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": false] as CFDictionary)
    }

    public static func requestIfNeeded() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    public static var onboardingMessage: String {
        """
        접근성 권한이 필요합니다.

        시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서
        이 명령을 실행한 터미널 앱(예: iTerm)을 추가하고 켜 주세요.

        \(settingsDeepLink)
        """
    }
}
```

`AXTrustedCheckOptionPrompt`를 리터럴로 쓴 것은 사전 확인 사항 2번 때문이다. `kAXTrustedCheckOptionPrompt` 상수를 쓰면 컴파일되지 않는다.

- [ ] **Step 4: main.swift에 권한 확인만 넣기**

`Sources/restage/main.swift`:

```swift
import RestageKitDarwin

if AccessibilityPermission.isTrusted() {
    print("accessibility: granted")
} else {
    print(AccessibilityPermission.onboardingMessage)
    _ = AccessibilityPermission.requestIfNeeded()
}
```

- [ ] **Step 5: 빌드 및 실행**

Run: `swift run restage`
Expected (권한 미승인 시): 온보딩 메시지가 출력되고 시스템 프롬프트가 뜬다.

- [ ] **Step 6: 권한 승인 후 재실행**

시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서 실행 중인 터미널 앱을 추가하고 켠다. 터미널 앱을 완전히 종료했다가 다시 연다(TCC 변경은 프로세스 재시작 후 반영된다).

Run: `swift run restage`
Expected: `accessibility: granted`

**이 출력이 나올 때까지 다음 태스크로 넘어가지 않는다.** 권한 없이는 이후 모든 AX 호출이 `-25211`을 반환하며, 그 상태에서 디버깅하면 존재하지 않는 버그를 쫓게 된다.

- [ ] **Step 7: 커밋**

```bash
git add Package.swift Sources
git commit -m "feat: 패키지 스캐폴딩과 접근성 권한 확인 추가"
```

---

## Task 2: Slot 좌표 계산

이 태스크만 진짜 TDD로 진행한다. 순수 함수이고 경계 조건에서 틀리기 쉽다.

**Files:**
- Create: `Sources/RestageKit/Slot.swift`
- Create: `Sources/RestageKit/SlotGeometry.swift`
- Test: `Tests/RestageKitTests/SlotGeometryTests.swift`

**좌표계 규약** (구현 전 반드시 이해할 것):

- 입력 `visibleFrame`은 `NSScreen.visibleFrame`. **bottom-left 원점**이고 y가 위로 증가한다. 메뉴바와 Dock 영역이 이미 제외되어 있다.
- 입력 `primaryMaxY`는 `NSScreen.screens[0].frame.maxY`. 주 디스플레이의 위쪽 경계다.
- 출력은 **AX 좌표계**. top-left 원점이고 y가 아래로 증가한다. 변환식은 `axY = primaryMaxY - cocoaRect.maxY`.
- 사분면 이름은 읽는 순서를 따른다. `q1` 좌상, `q2` 우상, `q3` 좌하, `q4` 우하.
- 홀수 크기 분할 시 남는 1pt는 왼쪽과 위쪽이 가져간다.
- `centered`는 `visibleFrame`의 가로 세로 각각 2/3 크기로 중앙 배치한다.

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/RestageKitTests/SlotGeometryTests.swift`:

```swift
import Testing
import CoreGraphics
@testable import RestageKit

// 주 디스플레이 하나, 1440x900, Dock 하단 70pt, 메뉴바 상단 25pt 가정.
// frame       = (0, 0, 1440, 900)   Cocoa 좌표
// visibleFrame = (0, 70, 1440, 805) Cocoa 좌표
private let vf = CGRect(x: 0, y: 70, width: 1440, height: 805)
private let primaryMaxY: CGFloat = 900

@Test func fullFillsVisibleFrameInAXCoordinates() {
    let r = SlotGeometry.frame(for: .full, in: vf, primaryMaxY: primaryMaxY)
    #expect(r == CGRect(x: 0, y: 25, width: 1440, height: 805))
}

@Test func leftHalfTakesLeftSide() {
    let r = SlotGeometry.frame(for: .leftHalf, in: vf, primaryMaxY: primaryMaxY)
    #expect(r == CGRect(x: 0, y: 25, width: 720, height: 805))
}

@Test func rightHalfStartsAtMidpoint() {
    let r = SlotGeometry.frame(for: .rightHalf, in: vf, primaryMaxY: primaryMaxY)
    #expect(r == CGRect(x: 720, y: 25, width: 720, height: 805))
}

@Test func oddWidthGivesExtraPixelToLeft() {
    let odd = CGRect(x: 0, y: 70, width: 1441, height: 805)
    let left = SlotGeometry.frame(for: .leftHalf, in: odd, primaryMaxY: primaryMaxY)
    let right = SlotGeometry.frame(for: .rightHalf, in: odd, primaryMaxY: primaryMaxY)
    #expect(left.width == 721)
    #expect(right.width == 720)
    #expect(left.maxX == right.minX)
}

@Test func topHalfIsAtSmallerAXY() {
    let r = SlotGeometry.frame(for: .topHalf, in: vf, primaryMaxY: primaryMaxY)
    #expect(r == CGRect(x: 0, y: 25, width: 1440, height: 403))
}

@Test func bottomHalfFollowsTopHalf() {
    let top = SlotGeometry.frame(for: .topHalf, in: vf, primaryMaxY: primaryMaxY)
    let bottom = SlotGeometry.frame(for: .bottomHalf, in: vf, primaryMaxY: primaryMaxY)
    #expect(bottom.minY == top.maxY)
    #expect(top.height + bottom.height == vf.height)
}

@Test func oddHeightGivesExtraPixelToTop() {
    let odd = CGRect(x: 0, y: 70, width: 1440, height: 805)
    let top = SlotGeometry.frame(for: .topHalf, in: odd, primaryMaxY: primaryMaxY)
    let bottom = SlotGeometry.frame(for: .bottomHalf, in: odd, primaryMaxY: primaryMaxY)
    #expect(top.height == 403)
    #expect(bottom.height == 402)
}

@Test func quadrantsTileTheVisibleFrame() {
    let q1 = SlotGeometry.frame(for: .q1, in: vf, primaryMaxY: primaryMaxY)
    let q2 = SlotGeometry.frame(for: .q2, in: vf, primaryMaxY: primaryMaxY)
    let q3 = SlotGeometry.frame(for: .q3, in: vf, primaryMaxY: primaryMaxY)
    let q4 = SlotGeometry.frame(for: .q4, in: vf, primaryMaxY: primaryMaxY)

    #expect(q1.minX == 0 && q1.minY == 25)          // 좌상
    #expect(q2.minX == 720 && q2.minY == 25)        // 우상
    #expect(q3.minX == 0 && q3.minY == q1.maxY)     // 좌하
    #expect(q4.minX == 720 && q4.minY == q2.maxY)   // 우하

    let area = q1.width * q1.height + q2.width * q2.height
             + q3.width * q3.height + q4.width * q4.height
    #expect(area == vf.width * vf.height)
}

@Test func centeredIsTwoThirdsAndCentered() {
    let r = SlotGeometry.frame(for: .centered, in: vf, primaryMaxY: primaryMaxY)
    #expect(r.width == 960)
    #expect(r.height == 537)
    #expect(r.midX == vf.midX)
}

@Test func dockOnLeftShiftsOrigin() {
    // Dock 좌측 80pt: visibleFrame이 x=80에서 시작하고 아래는 메뉴바만 제외
    let leftDock = CGRect(x: 80, y: 0, width: 1360, height: 875)
    let r = SlotGeometry.frame(for: .leftHalf, in: leftDock, primaryMaxY: primaryMaxY)
    #expect(r.minX == 80)
    #expect(r.width == 680)
    #expect(r.minY == 25)
}

@Test func secondaryDisplayAboveOriginGetsNegativeAXY() {
    // 주 디스플레이 위에 배치된 외장 모니터: Cocoa y가 900 이상
    let above = CGRect(x: 0, y: 900, width: 1920, height: 1080)
    let r = SlotGeometry.frame(for: .full, in: above, primaryMaxY: primaryMaxY)
    #expect(r.minY == -1080)
}
```

- [ ] **Step 2: 테스트가 실패하는지 확인**

Run: `swift test --filter SlotGeometryTests`
Expected: 컴파일 실패. `cannot find 'SlotGeometry' in scope`

- [ ] **Step 3: Slot 열거형 구현**

`Sources/RestageKit/Slot.swift`:

```swift
public enum Slot: String, CaseIterable, Sendable {
    case full
    case leftHalf = "left-half"
    case rightHalf = "right-half"
    case topHalf = "top-half"
    case bottomHalf = "bottom-half"
    case q1
    case q2
    case q3
    case q4
    case centered
}
```

- [ ] **Step 4: SlotGeometry 구현**

`Sources/RestageKit/SlotGeometry.swift`:

```swift
import CoreGraphics

public enum SlotGeometry {
    private static let centeredRatio: CGFloat = 2.0 / 3.0

    /// slot을 AX 좌표계(top-left 원점) 사각형으로 변환한다.
    /// - Parameters:
    ///   - visibleFrame: `NSScreen.visibleFrame`. Cocoa 좌표계(bottom-left 원점).
    ///   - primaryMaxY: `NSScreen.screens[0].frame.maxY`. 좌표계 변환 기준선.
    public static func frame(for slot: Slot, in visibleFrame: CGRect, primaryMaxY: CGFloat) -> CGRect {
        toAX(cocoaFrame(for: slot, in: visibleFrame), primaryMaxY: primaryMaxY)
    }

    private static func cocoaFrame(for slot: Slot, in vf: CGRect) -> CGRect {
        let leftWidth = (vf.width / 2).rounded(.up)
        let rightWidth = vf.width - leftWidth
        let topHeight = (vf.height / 2).rounded(.up)
        let bottomHeight = vf.height - topHeight
        let topY = vf.maxY - topHeight

        switch slot {
        case .full:
            return vf
        case .leftHalf:
            return CGRect(x: vf.minX, y: vf.minY, width: leftWidth, height: vf.height)
        case .rightHalf:
            return CGRect(x: vf.minX + leftWidth, y: vf.minY, width: rightWidth, height: vf.height)
        case .topHalf:
            return CGRect(x: vf.minX, y: topY, width: vf.width, height: topHeight)
        case .bottomHalf:
            return CGRect(x: vf.minX, y: vf.minY, width: vf.width, height: bottomHeight)
        case .q1:
            return CGRect(x: vf.minX, y: topY, width: leftWidth, height: topHeight)
        case .q2:
            return CGRect(x: vf.minX + leftWidth, y: topY, width: rightWidth, height: topHeight)
        case .q3:
            return CGRect(x: vf.minX, y: vf.minY, width: leftWidth, height: bottomHeight)
        case .q4:
            return CGRect(x: vf.minX + leftWidth, y: vf.minY, width: rightWidth, height: bottomHeight)
        case .centered:
            let width = (vf.width * centeredRatio).rounded()
            let height = (vf.height * centeredRatio).rounded()
            return CGRect(
                x: vf.minX + ((vf.width - width) / 2).rounded(),
                y: vf.minY + ((vf.height - height) / 2).rounded(),
                width: width,
                height: height)
        }
    }

    /// Cocoa 좌표계(bottom-left 원점, y 위로 증가)를 AX 좌표계(top-left 원점, y 아래로 증가)로 변환한다.
    /// 이 변환식은 프로젝트 전체에서 이 함수에만 존재해야 한다.
    private static func toAX(_ rect: CGRect, primaryMaxY: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryMaxY - rect.maxY, width: rect.width, height: rect.height)
    }
}
```

- [ ] **Step 5: 테스트 통과 확인**

Run: `swift test --filter SlotGeometryTests`
Expected: 11개 테스트 전부 PASS

실패하면 기대값을 고치지 말고 계산식을 고친다. 위 기대값은 좌표계 규약에서 직접 유도한 것이다.

- [ ] **Step 6: 커밋**

```bash
git add Sources/RestageKit/Slot.swift Sources/RestageKit/SlotGeometry.swift Tests/RestageKitTests
git commit -m "feat: slot 좌표 계산과 AX 좌표계 변환 추가"
```

---

## Task 3: 핵심 값 타입과 엔진 프로토콜

**Files:**
- Create: `Sources/RestageKit/CoreTypes.swift`
- Create: `Sources/RestageKit/PlacementResult.swift`
- Create: `Sources/RestageKit/EngineError.swift`
- Create: `Sources/RestageKit/WindowEngine.swift`
- Delete: `Sources/RestageKit/Placeholder.swift`

- [ ] **Step 1: 값 타입 정의**

`Sources/RestageKit/CoreTypes.swift`:

```swift
import CoreGraphics

/// 논리 앱 식별자. bundle ID 같은 OS 고유 값은 여기 들어오지 않는다.
public struct AppID: Hashable, Sendable, RawRepresentable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}

public struct ProcessHandle: Sendable {
    public let pid: Int32
    /// 이번 실행에서 새로 띄웠으면 true, 기존 프로세스를 찾았으면 false.
    public let wasLaunched: Bool

    public init(pid: Int32, wasLaunched: Bool) {
        self.pid = pid
        self.wasLaunched = wasLaunched
    }
}

public struct DisplayInfo: Sendable {
    /// Cocoa 좌표계(bottom-left 원점)의 가용 영역. 메뉴바와 Dock 제외.
    public let visibleFrame: CGRect
    /// 주 디스플레이 위쪽 경계. AX 좌표계 변환 기준.
    public let primaryMaxY: CGFloat

    public init(visibleFrame: CGRect, primaryMaxY: CGFloat) {
        self.visibleFrame = visibleFrame
        self.primaryMaxY = primaryMaxY
    }
}

/// 창에 대한 불투명 참조. 구현체가 OS 고유 핸들을 숨긴다.
///
/// 이름이 `WindowRef`가 아닌 이유: Carbon(HIToolbox)이 같은 이름의 타입을 정의하고 있어
/// ApplicationServices를 import한 파일에서 'WindowRef is ambiguous for type lookup' 에러가 난다.
///
/// `@MainActor`인 이유: 구현체가 AXUIElement를 들고 있어 액터 경계를 넘길 수 없다.
/// 비격리 프로토콜로 두면 AXWindow 적합화가 isolation mismatch 에러를 낸다.
@MainActor
public protocol WindowHandle {
    /// AX 좌표계 기준 현재 사각형. 조회 실패 시 nil.
    var currentFrame: CGRect? { get }
    /// 창이 주 디스플레이의 현재 Space에 보이는지 여부.
    var isOnActiveSpace: Bool { get }
}
```

- [ ] **Step 2: 결과 타입 정의**

`Sources/RestageKit/PlacementResult.swift`:

```swift
import CoreGraphics

public enum PlacementResult: Sendable {
    /// 목표 좌표에 도달했다. warnings가 비어있지 않으면 주의가 필요하지만 실패는 아니다.
    case ok(actual: CGRect, attempts: Int, elapsed: Duration, warnings: [String])

    /// 앱의 최소 크기 제약 때문에 목표에 도달할 수 없다. 통과로 취급한다.
    case constrained(actual: CGRect, expected: CGRect, minSize: CGSize)

    /// 도달하지 못했고 원인이 최소 크기 제약이 아니다.
    case failed(expected: CGRect, actual: CGRect?, reason: String)

    public var isPass: Bool {
        switch self {
        case .ok, .constrained: return true
        case .failed: return false
        }
    }

    public var label: String {
        switch self {
        case .ok(_, _, _, let warnings): return warnings.isEmpty ? "PASS" : "WARN"
        case .constrained: return "CONSTRAINED"
        case .failed: return "FAIL"
        }
    }
}
```

- [ ] **Step 3: 오류 타입 정의**

`Sources/RestageKit/EngineError.swift`:

```swift
public enum EngineError: Error, CustomStringConvertible {
    case accessibilityNotTrusted
    case unknownApp(AppID)
    case applicationNotFound(bundleID: String)
    case launchFailed(bundleID: String, underlying: String)
    case windowTimeout(pid: Int32, seconds: Double)
    case axDisabled

    public var description: String {
        switch self {
        case .accessibilityNotTrusted:
            return "접근성 권한이 없습니다. 시스템 설정에서 이 터미널 앱을 승인하세요."
        case .unknownApp(let id):
            return "레지스트리에 없는 앱입니다: \(id.rawValue)"
        case .applicationNotFound(let bundleID):
            return "설치되지 않은 앱입니다: \(bundleID)"
        case .launchFailed(let bundleID, let underlying):
            return "실행 실패: \(bundleID) — \(underlying)"
        case .windowTimeout(let pid, let seconds):
            return "\(seconds)초 안에 창이 뜨지 않았습니다 (pid \(pid))"
        case .axDisabled:
            return "AX API가 비활성 상태입니다 (kAXErrorAPIDisabled). 접근성 권한을 확인하세요."
        }
    }
}
```

- [ ] **Step 4: 엔진 프로토콜 정의**

`Sources/RestageKit/WindowEngine.swift`:

```swift
@MainActor
public protocol WindowEngine {
    func launch(_ app: AppID) async throws -> ProcessHandle
    func waitForWindow(_ handle: ProcessHandle, timeout: Duration) async throws -> WindowHandle
    func place(_ window: WindowHandle, slot: Slot, display: DisplayInfo) async -> PlacementResult
    func fullscreen(_ window: WindowHandle) async -> PlacementResult
}
```

`launch`가 `async`인 이유는 `NSWorkspace.openApplication`이 비동기 API이기 때문이다. 동기 변형은 완료 핸들러 기반이라 MainActor에서 세마포어로 기다리면 교착한다.

`@MainActor`를 붙인 이유는 AX와 AppKit 호출을 한 액터에 묶어 Swift 6의 Sendable 검사를 우회할 필요 없이 통과시키기 위해서다. `AXUIElement`는 Sendable이 아니므로 액터 경계를 넘기면 컴파일되지 않는다.

- [ ] **Step 5: Placeholder 제거 후 빌드**

```bash
rm Sources/RestageKit/Placeholder.swift
swift build
```

Expected: 빌드 성공

- [ ] **Step 6: 커밋**

```bash
git add -A Sources/RestageKit
git commit -m "feat: 엔진 프로토콜과 핵심 값 타입 정의"
```

---

## Task 4: AXWindow 래퍼

`AXUIElement` 직접 호출은 이 파일 안에만 존재한다.

**Files:**
- Create: `Sources/RestageKitDarwin/AXAttributes.swift`
- Create: `Sources/RestageKitDarwin/AXWindow.swift`

- [ ] **Step 1: 속성 이름 상수 정의**

`Sources/RestageKitDarwin/AXAttributes.swift`:

```swift
/// AX 속성 이름. Swift 6 strict concurrency에서 `kAX*` 전역 상수는
/// 'not concurrency-safe' 에러를 내므로 리터럴로 정의한다.
enum AXAttributes {
    static let windows = "AXWindows"
    static let role = "AXRole"
    static let position = "AXPosition"
    static let size = "AXSize"
    static let minSize = "AXMinSize"
    static let minimized = "AXMinimized"
    static let fullScreen = "AXFullScreen"
    static let fullScreenButton = "AXFullScreenButton"
    static let windowRole = "AXWindow"
    static let pressAction = "AXPress"
}
```

- [ ] **Step 2: AXWindow 구현**

`Sources/RestageKitDarwin/AXWindow.swift`:

```swift
import ApplicationServices
import CoreGraphics
import RestageKit

@MainActor
public struct AXWindow: WindowHandle {
    let element: AXUIElement

    init(element: AXUIElement) {
        self.element = element
    }

    /// 해당 프로세스의 창 목록. 첫 번째가 가장 최근 활성 창이다.
    /// AX가 비활성이면 EngineError.axDisabled를 던진다.
    static func windows(ofPID pid: Int32) throws -> [AXWindow] {
        let app = AXUIElementCreateApplication(pid)
        var raw: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(app, AXAttributes.windows as CFString, &raw)

        if status == .apiDisabled { throw EngineError.axDisabled }
        guard status == .success, let list = raw as? [AXUIElement] else { return [] }
        return list.map(AXWindow.init(element:))
    }

    // MARK: 조회

    public var currentFrame: CGRect? {
        guard let origin = point(AXAttributes.position),
              let extent = size(AXAttributes.size) else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    public var isOnActiveSpace: Bool {
        // AX 트리에 나타나고 크기가 조회되면 현재 Space에 있다고 본다.
        // 다른 Space의 창은 AXPosition 조회가 실패하거나 화면 밖 좌표를 반환한다.
        currentFrame != nil
    }

    var role: String? { string(AXAttributes.role) }
    var minSize: CGSize? { size(AXAttributes.minSize) }
    var isMinimized: Bool { bool(AXAttributes.minimized) ?? false }
    var isFullScreen: Bool { bool(AXAttributes.fullScreen) ?? false }
    var hasFullScreenButton: Bool { rawAttribute(AXAttributes.fullScreenButton) != nil }

    // MARK: 설정

    @discardableResult
    func setPosition(_ value: CGPoint) -> Bool {
        var mutable = value
        guard let axValue = AXValueCreate(.cgPoint, &mutable) else { return false }
        return AXUIElementSetAttributeValue(
            element, AXAttributes.position as CFString, axValue) == .success
    }

    @discardableResult
    func setSize(_ value: CGSize) -> Bool {
        var mutable = value
        guard let axValue = AXValueCreate(.cgSize, &mutable) else { return false }
        return AXUIElementSetAttributeValue(
            element, AXAttributes.size as CFString, axValue) == .success
    }

    @discardableResult
    func setMinimized(_ value: Bool) -> Bool {
        AXUIElementSetAttributeValue(
            element, AXAttributes.minimized as CFString, value as CFTypeRef) == .success
    }

    @discardableResult
    func setFullScreen(_ value: Bool) -> Bool {
        AXUIElementSetAttributeValue(
            element, AXAttributes.fullScreen as CFString, value as CFTypeRef) == .success
    }

    @discardableResult
    func pressFullScreenButton() -> Bool {
        guard let raw = rawAttribute(AXAttributes.fullScreenButton),
              CFGetTypeID(raw) == AXUIElementGetTypeID() else { return false }
        let button = unsafeDowncast(raw, to: AXUIElement.self)
        return AXUIElementPerformAction(button, AXAttributes.pressAction as CFString) == .success
    }

    // MARK: 저수준 접근자
    // AXValueGetValue를 제네릭 inout으로 감싸면 'forming UnsafeMutableRawPointer to
    // a variable of type T' 경고가 나므로 구체 타입별로 분리한다.

    private func rawAttribute(_ attribute: String) -> CFTypeRef? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &raw) == .success
        else { return nil }
        return raw
    }

    private func axValue(_ attribute: String) -> AXValue? {
        guard let raw = rawAttribute(attribute),
              CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        return unsafeDowncast(raw, to: AXValue.self)
    }

    private func point(_ attribute: String) -> CGPoint? {
        guard let value = axValue(attribute) else { return nil }
        var result = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &result) else { return nil }
        return result
    }

    private func size(_ attribute: String) -> CGSize? {
        guard let value = axValue(attribute) else { return nil }
        var result = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &result) else { return nil }
        return result
    }

    private func string(_ attribute: String) -> String? {
        rawAttribute(attribute) as? String
    }

    private func bool(_ attribute: String) -> Bool? {
        rawAttribute(attribute) as? Bool
    }
}
```

- [ ] **Step 3: 빌드**

Run: `swift build`
Expected: 빌드 성공, 경고 없음

경고가 나면 넘어가지 말고 해결한다. 특히 `forming 'UnsafeMutableRawPointer' to a variable of type 'T'` 경고가 보이면 제네릭 접근자가 남아 있는 것이다.

- [ ] **Step 4: 수동 확인용 임시 코드로 검증**

`Sources/restage/main.swift`를 다음으로 교체한다:

```swift
import AppKit
import RestageKit
import RestageKitDarwin

guard AccessibilityPermission.isTrusted() else {
    print(AccessibilityPermission.onboardingMessage)
    exit(1)
}

guard let finder = NSWorkspace.shared.runningApplications
        .first(where: { $0.bundleIdentifier == "com.apple.finder" }) else {
    print("Finder를 찾을 수 없습니다")
    exit(1)
}

let windows = try AXWindow.windows(ofPID: finder.processIdentifier)
print("Finder 창 개수: \(windows.count)")
for window in windows {
    print("  role=\(window.role ?? "?") frame=\(window.currentFrame.map(String.init(describing:)) ?? "n/a") minSize=\(window.minSize.map(String.init(describing:)) ?? "n/a")")
}
```

Run: `swift run restage`

Expected: Finder 창이 하나 이상 열려 있으면 `role=AXWindow`와 유효한 frame이 출력된다. 창이 없으면 Finder에서 새 창을 열고 다시 실행한다.

`Finder 창 개수: 0`이 계속 나오거나 `axDisabled`가 던져지면 Task 1의 권한 승인이 실제로 반영되지 않은 것이다. 터미널 앱을 완전히 종료 후 재실행한다.

- [ ] **Step 5: 커밋**

```bash
git add Sources/RestageKitDarwin Sources/restage
git commit -m "feat: AXUIElement 속성 접근 래퍼 추가"
```

---

## Task 5: AppRegistry

**Files:**
- Create: `Sources/RestageKitDarwin/AppRegistry.swift`
- Test: `Tests/RestageKitDarwinTests/AppRegistryTests.swift`

- [ ] **Step 1: 실패하는 테스트 작성**

`Tests/RestageKitDarwinTests/AppRegistryTests.swift`:

```swift
import Testing
import RestageKit
@testable import RestageKitDarwin

@Test func resolvesKnownApps() throws {
    #expect(try AppRegistry.bundleID(for: AppID("safari")) == "com.apple.Safari")
    #expect(try AppRegistry.bundleID(for: AppID("cursor")) == "com.todesktop.230313mzl4w4u92")
    #expect(try AppRegistry.bundleID(for: AppID("kakaotalk")) == "com.kakao.KakaoTalkMac")
}

@Test func rejectsUnknownApp() {
    #expect(throws: EngineError.self) {
        try AppRegistry.bundleID(for: AppID("nonexistent-app"))
    }
}

@Test func sampleSetHasTenApps() {
    #expect(AppRegistry.probeSample.count == 10)
}

@Test func everySampleAppResolves() throws {
    for app in AppRegistry.probeSample {
        _ = try AppRegistry.bundleID(for: app)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `swift test --filter AppRegistryTests`
Expected: 컴파일 실패. `cannot find 'AppRegistry' in scope`

- [ ] **Step 3: 구현**

`Sources/RestageKitDarwin/AppRegistry.swift`:

```swift
import RestageKit

/// 논리 앱 이름을 macOS bundle ID로 해석한다.
/// bundle ID 문자열은 프로젝트 전체에서 이 파일에만 존재해야 한다.
public enum AppRegistry {
    private static let mapping: [String: String] = [
        "safari": "com.apple.Safari",
        "iterm": "com.googlecode.iterm2",
        "xcode": "com.apple.dt.Xcode",
        "iina": "com.colliderli.iina",
        "chrome": "com.google.Chrome",
        "cursor": "com.todesktop.230313mzl4w4u92",
        "discord": "com.hnc.Discord",
        "notion": "notion.id",
        "claude": "com.anthropic.claudefordesktop",
        "kakaotalk": "com.kakao.KakaoTalkMac",
    ]

    /// 1단계 검증 표본. 실패 유형이 서로 다른 군을 덮도록 선정했다.
    public static let probeSample: [AppID] = [
        AppID("safari"),
        AppID("iterm"),
        AppID("xcode"),
        AppID("iina"),
        AppID("chrome"),
        AppID("cursor"),
        AppID("discord"),
        AppID("notion"),
        AppID("claude"),
        AppID("kakaotalk"),
    ]

    public static func bundleID(for app: AppID) throws -> String {
        guard let id = mapping[app.rawValue.lowercased()] else {
            throw EngineError.unknownApp(app)
        }
        return id
    }

    public static var knownApps: [AppID] {
        mapping.keys.sorted().map { AppID($0) }
    }
}
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `swift test --filter AppRegistryTests`
Expected: 4개 테스트 전부 PASS

- [ ] **Step 5: 커밋**

```bash
git add Sources/RestageKitDarwin/AppRegistry.swift Tests/RestageKitDarwinTests
git commit -m "feat: 논리 앱 이름 bundle ID 레지스트리 추가"
```

---

## Task 6: 폴링 유틸리티

고정 sleep을 쓰지 않는다는 원칙을 한곳에 구현한다.

**Files:**
- Create: `Sources/RestageKitDarwin/Polling.swift`

- [ ] **Step 1: 구현**

`Sources/RestageKitDarwin/Polling.swift`:

```swift
import Foundation

/// `@MainActor`인 이유: 호출자가 전부 MainActor 격리 타입이라
/// 비격리로 두면 클로저를 넘길 때 'sending value of non-Sendable type' 에러가 난다.
@MainActor
enum Polling {
    static let defaultInterval: Duration = .milliseconds(25)

    /// body가 nil이 아닌 값을 반환할 때까지 폴링한다. 타임아웃 시 nil.
    static func poll<T>(
        interval: Duration = defaultInterval,
        timeout: Duration,
        body: () throws -> T?
    ) async rethrows -> T? {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)

        while true {
            if let value = try body() { return value }
            if clock.now >= deadline { return nil }
            try? await Task.sleep(for: interval)
        }
    }

    /// sample이 연속 2회 같은 값을 반환할 때까지 폴링한다.
    /// Electron 앱이 배치 직후 스스로 크기를 되돌리는 동작이 끝난 시점을 잡는다.
    /// 타임아웃 시 마지막으로 관측한 값을 반환한다(관측 자체가 실패했으면 nil).
    static func settle<T: Equatable>(
        interval: Duration = defaultInterval,
        timeout: Duration,
        sample: () -> T?
    ) async -> T? {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        var previous: T? = sample()

        while clock.now < deadline {
            try? await Task.sleep(for: interval)
            let current = sample()
            if let current, current == previous { return current }
            previous = current
        }
        return previous
    }
}
```

- [ ] **Step 2: 빌드**

Run: `swift build`
Expected: 빌드 성공

- [ ] **Step 3: 커밋**

```bash
git add Sources/RestageKitDarwin/Polling.swift
git commit -m "feat: 안정 상태 판정을 포함한 폴링 유틸리티 추가"
```

---

## Task 7: AppLauncher와 DisplayProvider

**Files:**
- Create: `Sources/RestageKitDarwin/AppLauncher.swift`
- Create: `Sources/RestageKitDarwin/DisplayProvider.swift`

- [ ] **Step 1: AppLauncher 구현**

`Sources/RestageKitDarwin/AppLauncher.swift`:

```swift
import AppKit
import RestageKit

// probe(실행 타겟)에서 콜드 스타트를 위해 terminate를 호출하므로 public이다.
@MainActor
public enum AppLauncher {
    /// 이미 실행 중이면 그 프로세스를 반환하고, 아니면 새로 실행한다.
    public static func launch(bundleID: String) async throws -> ProcessHandle {
        if let running = runningApplication(bundleID: bundleID) {
            return ProcessHandle(pid: running.processIdentifier, wasLaunched: false)
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            throw EngineError.applicationNotFound(bundleID: bundleID)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        do {
            let app = try await NSWorkspace.shared.openApplication(
                at: url, configuration: configuration)
            return ProcessHandle(pid: app.processIdentifier, wasLaunched: true)
        } catch {
            throw EngineError.launchFailed(
                bundleID: bundleID, underlying: error.localizedDescription)
        }
    }

    public static func runningApplication(bundleID: String) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleID && !$0.isTerminated }
    }

    public static func isRunning(bundleID: String) -> Bool {
        runningApplication(bundleID: bundleID) != nil
    }

    /// probe의 콜드 스타트 케이스 전용. 앱을 종료하고 사라질 때까지 기다린다.
    public static func terminate(bundleID: String, timeout: Duration) async -> Bool {
        guard let app = runningApplication(bundleID: bundleID) else { return true }
        app.terminate()

        let gone = await Polling.poll(interval: .milliseconds(100), timeout: timeout) {
            isRunning(bundleID: bundleID) ? nil : true
        }
        if gone == true { return true }

        app.forceTerminate()
        let forced = await Polling.poll(interval: .milliseconds(100), timeout: .seconds(3)) {
            isRunning(bundleID: bundleID) ? nil : true
        }
        return forced == true
    }
}
```

`configuration.activates = false`로 둔 이유는 실행 순서대로 앱이 포커스를 뺏어가면 마지막에 anchor로 포커스를 주는 동작(후속 사이클)과 충돌하기 때문이다.

- [ ] **Step 2: DisplayProvider 구현**

`Sources/RestageKitDarwin/DisplayProvider.swift`:

```swift
import AppKit
import RestageKit

@MainActor
public enum DisplayProvider {
    /// 주 디스플레이 정보. 멀티 디스플레이 선택은 후속 사이클에서 추가한다.
    public static func primary() -> DisplayInfo? {
        guard let main = NSScreen.main, let first = NSScreen.screens.first else { return nil }
        return DisplayInfo(visibleFrame: main.visibleFrame, primaryMaxY: first.frame.maxY)
    }
}
```

- [ ] **Step 3: 빌드**

Run: `swift build`
Expected: 빌드 성공

- [ ] **Step 4: 커밋**

```bash
git add Sources/RestageKitDarwin/AppLauncher.swift Sources/RestageKitDarwin/DisplayProvider.swift
git commit -m "feat: 앱 실행 탐지와 디스플레이 정보 조회 추가"
```

---

## Task 8: WindowWaiter

**Files:**
- Create: `Sources/RestageKitDarwin/WindowWaiter.swift`

- [ ] **Step 1: 구현**

`Sources/RestageKitDarwin/WindowWaiter.swift`:

```swift
import RestageKit

@MainActor
enum WindowWaiter {
    /// 배치 가능한 창이 나타날 때까지 폴링한다.
    /// 조건: AXRole == AXWindow, 크기가 0보다 큼, 최소화 아님.
    /// 반환값은 AX 창 목록의 첫 번째, 즉 가장 최근 활성 창이다.
    static func wait(pid: Int32, timeout: Duration) async throws -> AXWindow {
        var lastError: Error?

        let found = await Polling.poll(timeout: timeout) { () -> AXWindow? in
            do {
                let windows = try AXWindow.windows(ofPID: pid)
                return windows.first(where: isPlaceable)
            } catch {
                lastError = error
                return nil
            }
        }

        if let found { return found }
        if let lastError { throw lastError }
        throw EngineError.windowTimeout(pid: pid, seconds: seconds(of: timeout))
    }

    /// 배치 전 창 상태를 정리한다. 최소화 해제, 필요 시 전체화면 해제.
    /// 크기가 안정될 때까지 기다린 뒤 반환한다.
    static func prepareForDesktopPlacement(_ window: AXWindow) async {
        if window.isMinimized {
            window.setMinimized(false)
            _ = await Polling.settle(timeout: .seconds(2)) { window.currentFrame }
        }
        if window.isFullScreen {
            window.setFullScreen(false)
            _ = await Polling.settle(timeout: .seconds(3)) { window.currentFrame }
        }
    }

    private static func isPlaceable(_ window: AXWindow) -> Bool {
        guard window.role == AXAttributes.windowRole else { return false }
        guard !window.isMinimized else { return false }
        guard let frame = window.currentFrame else { return false }
        return frame.width > 0 && frame.height > 0
    }

    private static func seconds(of duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
```

최소화된 창을 `isPlaceable`에서 제외하면서 동시에 `prepareForDesktopPlacement`에서 해제하는 것이 모순처럼 보일 수 있다. 의도는 이렇다. 앱에 창이 여러 개 있고 그중 하나만 최소화되어 있으면 최소화되지 않은 창을 고르는 게 맞다. 창이 전부 최소화되어 있으면 `wait`가 타임아웃하는데, 이 경우는 Task 13에서 실제로 발생하는지 확인하고 필요하면 폴백을 추가한다. 지금 미리 넣지 않는다.

- [ ] **Step 2: 빌드**

Run: `swift build`
Expected: 빌드 성공

- [ ] **Step 3: 커밋**

```bash
git add Sources/RestageKitDarwin/WindowWaiter.swift
git commit -m "feat: 창 등장 대기 폴링과 배치 전 상태 정리 추가"
```

---

## Task 9: WindowPlacer 수렴 루프

이 프로젝트에서 가장 중요한 파일이다.

**Files:**
- Create: `Sources/RestageKitDarwin/WindowPlacer.swift`

- [ ] **Step 1: 구현**

`Sources/RestageKitDarwin/WindowPlacer.swift`:

```swift
import CoreGraphics
import Foundation
import RestageKit

@MainActor
enum WindowPlacer {
    static let tolerance: CGFloat = 2
    static let maxAttempts = 3
    static let totalTimeout: Duration = .seconds(3)
    static let settleTimeout: Duration = .milliseconds(800)

    static func place(_ window: AXWindow, target: CGRect) async -> PlacementResult {
        let clock = ContinuousClock()
        let start = clock.now
        let deadline = start.advanced(by: totalTimeout)
        var lastObserved: CGRect?

        for attempt in 1...maxAttempts {
            apply(target, to: window)

            let settled = await Polling.settle(timeout: settleTimeout) { window.currentFrame }
            lastObserved = settled

            guard let settled else {
                if clock.now >= deadline { break }
                continue
            }

            if matches(settled, target) {
                var warnings: [String] = []
                if !window.isOnActiveSpace {
                    warnings.append("다른 Space에 있어 화면에 보이지 않습니다")
                }
                return .ok(
                    actual: settled,
                    attempts: attempt,
                    elapsed: start.duration(to: clock.now),
                    warnings: warnings)
            }

            if clock.now >= deadline { break }
        }

        return classifyFailure(window, target: target, observed: lastObserved)
    }

    /// 적용 순서. 멀티 디스플레이 지원 시 position → size → position 3단으로 교체한다.
    /// 지금은 주 디스플레이만 다루므로 화면 경계 clamp가 발생하지 않는다.
    private static func apply(_ target: CGRect, to window: AXWindow) {
        window.setPosition(target.origin)
        window.setSize(target.size)
    }

    private static func matches(_ actual: CGRect, _ target: CGRect) -> Bool {
        abs(actual.minX - target.minX) <= tolerance
            && abs(actual.minY - target.minY) <= tolerance
            && abs(actual.width - target.width) <= tolerance
            && abs(actual.height - target.height) <= tolerance
    }

    /// 도달 실패의 원인이 앱의 최소 크기 제약인지 판별한다.
    /// 제약이 원인이면 고칠 수 없는 것이므로 실패가 아니라 constrained로 분류한다.
    private static func classifyFailure(
        _ window: AXWindow, target: CGRect, observed: CGRect?
    ) -> PlacementResult {
        guard let observed else {
            return .failed(expected: target, actual: nil, reason: "창 좌표를 조회할 수 없습니다")
        }

        if let minSize = window.minSize {
            let widthBlocked = target.width < minSize.width - tolerance
            let heightBlocked = target.height < minSize.height - tolerance
            let widthSettledAtMin = abs(observed.width - minSize.width) <= tolerance
            let heightSettledAtMin = abs(observed.height - minSize.height) <= tolerance

            if (widthBlocked && widthSettledAtMin) || (heightBlocked && heightSettledAtMin) {
                return .constrained(actual: observed, expected: target, minSize: minSize)
            }
        }

        return .failed(
            expected: target,
            actual: observed,
            reason: "\(maxAttempts)회 시도 후에도 목표 좌표에 도달하지 못했습니다")
    }
}
```

- [ ] **Step 2: 빌드**

Run: `swift build`
Expected: 빌드 성공

- [ ] **Step 3: 커밋**

```bash
git add Sources/RestageKitDarwin/WindowPlacer.swift
git commit -m "feat: 배치 수렴 루프와 최소 크기 제약 판별 추가"
```

---

## Task 10: AXWindowEngine 조립

**Files:**
- Create: `Sources/RestageKitDarwin/AXWindowEngine.swift`

- [ ] **Step 1: 구현**

`fullscreen`은 Task 14에서 채운다. 지금은 컴파일을 위해 명시적 미구현 결과를 반환한다.

`Sources/RestageKitDarwin/AXWindowEngine.swift`:

```swift
import CoreGraphics
import RestageKit

@MainActor
public struct AXWindowEngine: WindowEngine {
    public init() {}

    public func launch(_ app: AppID) async throws -> ProcessHandle {
        guard AccessibilityPermission.isTrusted() else {
            throw EngineError.accessibilityNotTrusted
        }
        let bundleID = try AppRegistry.bundleID(for: app)
        return try await AppLauncher.launch(bundleID: bundleID)
    }

    public func waitForWindow(
        _ handle: ProcessHandle, timeout: Duration
    ) async throws -> WindowHandle {
        try await WindowWaiter.wait(pid: handle.pid, timeout: timeout)
    }

    public func place(
        _ window: WindowHandle, slot: Slot, display: DisplayInfo
    ) async -> PlacementResult {
        guard let axWindow = window as? AXWindow else {
            return .failed(expected: .zero, actual: nil, reason: "지원하지 않는 WindowHandle 구현")
        }
        await WindowWaiter.prepareForDesktopPlacement(axWindow)
        let target = SlotGeometry.frame(
            for: slot, in: display.visibleFrame, primaryMaxY: display.primaryMaxY)
        return await WindowPlacer.place(axWindow, target: target)
    }

    public func fullscreen(_ window: WindowHandle) async -> PlacementResult {
        .failed(expected: .zero, actual: nil, reason: "미구현")
    }
}
```

- [ ] **Step 2: 빌드**

Run: `swift build`
Expected: 빌드 성공

`AXWindow`를 `WindowHandle`로 다운캐스트하는 부분에서 에러가 나면 Task 3의 `WindowHandle`에 `@MainActor`가 빠진 것이다.

- [ ] **Step 3: 커밋**

```bash
git add Sources/RestageKit/WindowEngine.swift Sources/RestageKitDarwin/AXWindowEngine.swift
git commit -m "feat: AX 기반 WindowEngine 구현 조립"
```

---

## Task 11: ProbeReport

**Files:**
- Create: `Sources/restage/ProbeReport.swift`

- [ ] **Step 1: 구현**

`Sources/restage/ProbeReport.swift`:

```swift
import CoreGraphics
import Foundation
import RestageKit

struct ProbeRow {
    let app: String
    let start: String       // "cold" 또는 "warm"
    let label: String
    let expected: CGRect?
    let actual: CGRect?
    let attempts: Int?
    let elapsedMS: Int?
    let note: String
}

enum ProbeReport {
    static func row(app: AppID, start: String, result: PlacementResult) -> ProbeRow {
        switch result {
        case .ok(let actual, let attempts, let elapsed, let warnings):
            return ProbeRow(
                app: app.rawValue, start: start, label: result.label,
                expected: nil, actual: actual, attempts: attempts,
                elapsedMS: milliseconds(elapsed), note: warnings.joined(separator: "; "))
        case .constrained(let actual, let expected, let minSize):
            return ProbeRow(
                app: app.rawValue, start: start, label: result.label,
                expected: expected, actual: actual, attempts: nil, elapsedMS: nil,
                note: "최소 크기 \(fmt(minSize))")
        case .failed(let expected, let actual, let reason):
            return ProbeRow(
                app: app.rawValue, start: start, label: result.label,
                expected: expected, actual: actual, attempts: nil, elapsedMS: nil,
                note: reason)
        }
    }

    static func errorRow(app: AppID, start: String, error: Error) -> ProbeRow {
        ProbeRow(
            app: app.rawValue, start: start, label: "FAIL",
            expected: nil, actual: nil, attempts: nil, elapsedMS: nil,
            note: String(describing: error))
    }

    // 표 정렬은 String(format:)의 %s를 쓰지 않는다. %s는 C 문자열을 기대하므로
    // Swift String을 넘기면 런타임에 출력이 깨진다. 패딩을 직접 처리한다.
    private static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }

    private static func padLeft(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
    }

    static func render(_ rows: [ProbeRow]) -> String {
        var lines: [String] = []
        lines.append(
            pad("APP", 12) + pad("START", 8) + pad("RESULT", 13)
            + pad("EXPECTED", 23) + pad("ACTUAL", 23)
            + padLeft("TRY", 4) + padLeft("MS", 8) + "  NOTE")
        lines.append(String(repeating: "-", count: 110))

        for row in rows {
            lines.append(
                pad(row.app, 12) + pad(row.start, 8) + pad(row.label, 13)
                + pad(row.expected.map(fmt) ?? "-", 23)
                + pad(row.actual.map(fmt) ?? "-", 23)
                + padLeft(row.attempts.map(String.init) ?? "-", 4)
                + padLeft(row.elapsedMS.map(String.init) ?? "-", 8)
                + "  " + row.note)
        }

        lines.append("")
        lines.append(summary(rows))
        return lines.joined(separator: "\n")
    }

    static func summary(_ rows: [ProbeRow]) -> String {
        let counts = Dictionary(grouping: rows, by: \.label).mapValues(\.count)
        let order = ["PASS", "WARN", "CONSTRAINED", "FAIL"]
        let parts = order.compactMap { key -> String? in
            guard let count = counts[key] else { return nil }
            return "\(key) \(count)"
        }
        let failed = counts["FAIL"] ?? 0
        let verdict = failed == 0 ? "GATE PASSED" : "GATE FAILED"
        return "\(parts.joined(separator: " / "))  총 \(rows.count)건 — \(verdict)"
    }

    static func hasFailure(_ rows: [ProbeRow]) -> Bool {
        rows.contains { $0.label == "FAIL" }
    }

    private static func fmt(_ rect: CGRect) -> String {
        String(format: "%.0f,%.0f %.0fx%.0f",
               rect.minX, rect.minY, rect.width, rect.height)
    }

    private static func fmt(_ size: CGSize) -> String {
        String(format: "%.0fx%.0f", size.width, size.height)
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        let components = duration.components
        return Int(components.seconds) * 1000 + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}
```

- [ ] **Step 2: 빌드**

Run: `swift build`
Expected: 빌드 성공

- [ ] **Step 3: 커밋**

```bash
git add Sources/restage/ProbeReport.swift
git commit -m "feat: probe 결과 표 출력 추가"
```

---

## Task 12: ProbeCommand와 진입점

**Files:**
- Create: `Sources/restage/ProbeCommand.swift`
- Modify: `Sources/restage/main.swift` (Task 4의 임시 코드를 전부 교체)

인자 파싱은 손으로 짠다. 플래그가 셋뿐이라 `swift-argument-parser` 의존성을 추가할 이유가 없다. 본격 CLI(`ws open`, `ws list`)를 만드는 후속 사이클에서 도입을 검토한다.

- [ ] **Step 1: ProbeCommand 구현**

`Sources/restage/ProbeCommand.swift`:

```swift
import Foundation
import RestageKit
import RestageKitDarwin

struct ProbeOptions {
    var slot: Slot = .leftHalf
    var apps: [AppID] = AppRegistry.probeSample
    var includeFullScreen = false

    static func parse(_ arguments: [String]) throws -> ProbeOptions {
        var options = ProbeOptions()
        var index = 0

        while index < arguments.count {
            switch arguments[index] {
            case "--slot":
                index += 1
                guard index < arguments.count, let slot = Slot(rawValue: arguments[index]) else {
                    throw ProbeError.usage("--slot 값이 올바르지 않습니다. 가능한 값: "
                        + Slot.allCases.map(\.rawValue).joined(separator: ", "))
                }
                options.slot = slot
            case "--app":
                index += 1
                guard index < arguments.count else {
                    throw ProbeError.usage("--app 뒤에 앱 이름이 필요합니다")
                }
                options.apps = [AppID(arguments[index])]
            case "--fullscreen":
                options.includeFullScreen = true
            default:
                throw ProbeError.usage("알 수 없는 인자: \(arguments[index])")
            }
            index += 1
        }
        return options
    }
}

enum ProbeError: Error, CustomStringConvertible {
    case usage(String)
    var description: String {
        switch self { case .usage(let message): return message }
    }
}

@MainActor
enum ProbeCommand {
    static let windowTimeout: Duration = .seconds(5)
    static let terminateTimeout: Duration = .seconds(5)

    static func run(_ options: ProbeOptions) async -> Int32 {
        guard AccessibilityPermission.isTrusted() else {
            print(AccessibilityPermission.onboardingMessage)
            return 1
        }
        guard let display = DisplayProvider.primary() else {
            print("디스플레이 정보를 조회할 수 없습니다")
            return 1
        }

        let engine = AXWindowEngine()
        var rows: [ProbeRow] = []

        for app in options.apps {
            rows.append(await coldStart(app, engine: engine, display: display, options: options))
            rows.append(await warmStart(app, engine: engine, display: display, options: options))
        }

        print(ProbeReport.render(rows))
        return ProbeReport.hasFailure(rows) ? 1 : 0
    }

    private static func coldStart(
        _ app: AppID, engine: AXWindowEngine, display: DisplayInfo, options: ProbeOptions
    ) async -> ProbeRow {
        do {
            let bundleID = try AppRegistry.bundleID(for: app)
            _ = await AppLauncher.terminate(bundleID: bundleID, timeout: terminateTimeout)
            return await placeOnce(app, start: "cold", engine: engine, display: display, options: options)
        } catch {
            return ProbeReport.errorRow(app: app, start: "cold", error: error)
        }
    }

    private static func warmStart(
        _ app: AppID, engine: AXWindowEngine, display: DisplayInfo, options: ProbeOptions
    ) async -> ProbeRow {
        await placeOnce(app, start: "warm", engine: engine, display: display, options: options)
    }

    private static func placeOnce(
        _ app: AppID, start: String, engine: AXWindowEngine,
        display: DisplayInfo, options: ProbeOptions
    ) async -> ProbeRow {
        do {
            let handle = try await engine.launch(app)
            let window = try await engine.waitForWindow(handle, timeout: windowTimeout)
            let result = await engine.place(window, slot: options.slot, display: display)

            guard options.includeFullScreen, result.isPass else {
                return ProbeReport.row(app: app, start: start, result: result)
            }
            let fullScreenResult = await engine.fullscreen(window)
            return ProbeReport.row(app: app, start: start + "+fs", result: fullScreenResult)
        } catch {
            return ProbeReport.errorRow(app: app, start: start, error: error)
        }
    }
}
```

- [ ] **Step 2: main.swift 교체**

`Sources/restage/main.swift`:

```swift
import Foundation
import RestageKitDarwin

let usage = """
restage — 워크스페이스 복원 도구

사용법:
  restage probe [--slot <slot>] [--app <name>] [--fullscreen]

옵션:
  --slot <slot>   배치할 위치. 기본값 left-half
  --app <name>    단일 앱만 검증. 기본값은 표본 10종 전부
  --fullscreen    배치 후 전체화면 전환까지 검증
"""

let arguments = Array(CommandLine.arguments.dropFirst())

guard let command = arguments.first else {
    print(usage)
    exit(2)
}

switch command {
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

- [ ] **Step 3: 빌드 및 단일 앱 실행**

Run: `swift run restage probe --app safari --slot left-half`

Expected: Safari가 종료되었다가 다시 뜨고, 좌측 절반에 배치되며, 표가 두 줄(cold, warm) 출력된다.

배치는 눈으로 보이는데 표에 FAIL이 뜨면 `EXPECTED`와 `ACTUAL` 값을 비교한다. y값이 크게 어긋나면 좌표계 변환 문제이므로 Task 2의 테스트를 다시 본다.

- [ ] **Step 4: 커밋**

```bash
git add Sources/restage
git commit -m "feat: probe 서브커맨드와 CLI 진입점 추가"
```

---

## Task 13: 1단계 검증 게이트

코드를 쓰는 태스크가 아니라 **성공률을 100%로 끌어올리는 태스크**다. 여기서 나온 실패를 고치는 것이 이 사이클의 실제 작업이다.

**Files:**
- Modify: 실패 원인에 따라 `WindowWaiter.swift`, `WindowPlacer.swift`, `AXWindow.swift`
- Create: `docs/superpowers/plans/2026-08-23-probe-results.md`

- [ ] **Step 1: 측정 환경 정리**

Rectangle을 종료한다. 창 관리자가 배치 직후 창을 다시 잡으면 측정이 오염된다.

```bash
osascript -e 'tell application "Rectangle" to quit' 2>/dev/null || true
pgrep -x Rectangle || echo "Rectangle 종료됨"
```

Expected: `Rectangle 종료됨`

- [ ] **Step 2: 전체 표본 실행**

Run: `swift run restage probe --slot left-half 2>&1 | tee /tmp/probe-left-half.txt`

Expected: 20행(10종 × cold/warm)과 요약 한 줄.

- [ ] **Step 3: 실패 분류**

`FAIL` 행마다 원인을 다음 셋 중 하나로 분류하고 대응한다.

| 증상 | 원인 | 대응 |
|---|---|---|
| `창이 뜨지 않았습니다` (Xcode 등 느린 앱) | `windowTimeout` 5초 부족 | 실측 기동 시간을 재고 타임아웃 상향. 앱별 예외가 아니라 전역 값으로 조정 |
| `ACTUAL`이 목표와 다르고 `minSize`도 아님 (Electron) | 되돌림이 `settleTimeout` 800ms보다 늦음 | `settleTimeout` 상향. 그래도 안 되면 `maxAttempts` 상향 |
| `role`이 `AXWindow`가 아님 (KakaoTalk 등) | 실제 창이 비표준 role | 해당 앱의 AX 트리를 덤프해 실제 role 확인 후 `isPlaceable` 조건 보완 |
| `창 좌표를 조회할 수 없습니다` | 다른 Space에 있음 | `WARN`으로 분류되는지 확인. 안 되면 `isOnActiveSpace` 판정 보완 |

AX 트리 덤프가 필요하면 임시로 다음을 `main.swift`에 넣어 실행한다(확인 후 제거).

```swift
// 디버그용: 특정 앱의 모든 창 role과 frame 덤프.
// main.swift 최상위 코드는 throw할 수 없으므로 do/catch로 감싼다.
do {
    let bundleID = try AppRegistry.bundleID(for: AppID("kakaotalk"))
    if let app = AppLauncher.runningApplication(bundleID: bundleID) {
        for window in try AXWindow.windows(ofPID: app.processIdentifier) {
            let frame = window.currentFrame.map(String.init(describing:)) ?? "nil"
            let min = window.minSize.map(String.init(describing:)) ?? "nil"
            print("role=\(window.role ?? "nil") frame=\(frame) min=\(min)")
        }
    }
} catch {
    print("덤프 실패: \(error)")
}
```

`AppLauncher`와 `AXWindow`는 현재 internal이므로 이 스니펫을 쓰려면 임시로 `public`을 붙이거나, 덤프 코드를 `RestageKitDarwin` 안의 임시 함수로 넣고 그것만 노출한다. 확인이 끝나면 되돌린다.

- [ ] **Step 4: 수정 후 재실행 반복**

`FAIL 0`이 될 때까지 Step 2~3을 반복한다. `CONSTRAINED`와 `WARN`은 통과다.

Run: `swift run restage probe --slot left-half`
Expected 마지막 줄: `... — GATE PASSED`

- [ ] **Step 5: 다른 slot으로 교차 확인**

Run: `swift run restage probe --slot q1`
Run: `swift run restage probe --slot centered`

Expected: 둘 다 `GATE PASSED`

`left-half`만 통과하고 `q1`이 실패하면 좌표 계산이 아니라 특정 크기에서만 나타나는 문제다. 두 케이스의 `EXPECTED`를 비교해 어느 축이 어긋나는지 본다.

- [ ] **Step 6: 결과 기록**

`docs/superpowers/plans/2026-08-23-probe-results.md`에 최종 실행의 표 전문을 붙이고, 각 `CONSTRAINED` 항목에 대해 어떤 앱의 최소 크기가 얼마인지 한 줄씩 적는다. 조정한 타임아웃 값과 그 근거(실측 기동 시간)도 적는다.

- [ ] **Step 7: 커밋**

```bash
git add -A
git commit -m "fix: 표본 10종 좌측 절반 배치 100% 통과"
```

---

## Task 14: FullScreenController

**Files:**
- Create: `Sources/RestageKitDarwin/FullScreenController.swift`
- Modify: `Sources/RestageKitDarwin/AXWindowEngine.swift` (`fullscreen` 미구현 반환을 교체)

- [ ] **Step 1: 구현**

`Sources/RestageKitDarwin/FullScreenController.swift`:

```swift
import CoreGraphics
import Foundation
import RestageKit

@MainActor
enum FullScreenController {
    static let transitionTimeout: Duration = .seconds(3)

    static func enter(_ window: AXWindow) async -> PlacementResult {
        let before = window.currentFrame

        if window.isFullScreen {
            return .ok(actual: before ?? .zero, attempts: 0, elapsed: .zero, warnings: [])
        }

        let clock = ContinuousClock()
        let start = clock.now

        // 1차: AXFullScreen 속성 직접 설정
        if window.setFullScreen(true), await confirmed(window) {
            return success(window, start: start, attempts: 1)
        }

        // 2차: 초록 버튼에 AXPress
        guard window.hasFullScreenButton else {
            return .failed(
                expected: before ?? .zero, actual: window.currentFrame,
                reason: "AXFullScreen 설정 실패, AXFullScreenButton도 없음")
        }
        if window.pressFullScreenButton(), await confirmed(window) {
            return success(window, start: start, attempts: 2)
        }

        return .failed(
            expected: before ?? .zero, actual: window.currentFrame,
            reason: "전체화면 전환이 \(transitionTimeout)안에 완료되지 않았습니다")
    }

    static func exit(_ window: AXWindow) async {
        guard window.isFullScreen else { return }
        window.setFullScreen(false)
        _ = await Polling.settle(timeout: transitionTimeout) { window.currentFrame }
    }

    /// AXFullScreen이 true가 되고 창 크기가 안정될 때까지 기다린다.
    private static func confirmed(_ window: AXWindow) async -> Bool {
        let flagged = await Polling.poll(timeout: transitionTimeout) {
            window.isFullScreen ? true : nil
        }
        guard flagged == true else { return false }
        _ = await Polling.settle(timeout: transitionTimeout) { window.currentFrame }
        return true
    }

    private static func success(
        _ window: AXWindow, start: ContinuousClock.Instant, attempts: Int
    ) -> PlacementResult {
        .ok(
            actual: window.currentFrame ?? .zero,
            attempts: attempts,
            elapsed: start.duration(to: ContinuousClock().now),
            warnings: [])
    }
}
```

- [ ] **Step 2: 엔진에 연결**

`AXWindowEngine.fullscreen`을 다음으로 교체:

```swift
    public func fullscreen(_ window: WindowHandle) async -> PlacementResult {
        guard let axWindow = window as? AXWindow else {
            return .failed(expected: .zero, actual: nil, reason: "지원하지 않는 WindowHandle 구현")
        }
        return await FullScreenController.enter(axWindow)
    }
```

- [ ] **Step 3: 단일 앱으로 확인**

Run: `swift run restage probe --app safari --slot left-half --fullscreen`

Expected: Safari가 좌측 절반에 배치된 뒤 전체화면으로 전환되고, 표에 `cold+fs`, `warm+fs` 행이 `PASS`로 나온다.

전체화면 상태로 남은 Safari는 수동으로 해제한다(`ctrl+cmd+F`).

- [ ] **Step 4: 커밋**

```bash
git add Sources/RestageKitDarwin
git commit -m "feat: 네이티브 전체화면 전환 추가"
```

---

## Task 15: 2단계 검증 게이트

- [ ] **Step 1: 전체 표본 전체화면 검증**

Run: `swift run restage probe --slot left-half --fullscreen 2>&1 | tee /tmp/probe-fullscreen.txt`

Expected: 20행 전부 `PASS` 또는 `CONSTRAINED`.

- [ ] **Step 2: 실패 분류**

| 증상 | 원인 | 대응 |
|---|---|---|
| `AXFullScreen 설정 실패, AXFullScreenButton도 없음` | 전체화면을 지원하지 않는 창 | 해당 앱이 실제로 초록 버튼을 갖는지 눈으로 확인. 없으면 `CONSTRAINED`로 분류하도록 `FullScreenController`를 보완 |
| 전환 타임아웃 | 3초 부족 | 실측 전환 시간을 재고 상향 |
| 전환은 됐는데 `isFullScreen`이 false | 앱이 자체 전체화면(비 네이티브)을 씀 | 창 크기가 화면 전체와 일치하는지로 폴백 판정 추가 |

- [ ] **Step 3: 반복 실행으로 멱등성 확인**

전체화면 상태에서 같은 명령을 한 번 더 돌린다.

Run: `swift run restage probe --slot left-half --fullscreen`

Expected: 결과가 1회차와 동일하다. `WindowWaiter.prepareForDesktopPlacement`가 전체화면을 해제하고 다시 배치한 뒤 전체화면으로 돌아가야 한다.

이것이 전체 스펙 9절의 "동일 워크스페이스 2회 연속 실행 → 결과 동일(멱등)"에 해당하는 검증이다.

- [ ] **Step 4: 결과 기록 및 커밋**

`docs/superpowers/plans/2026-08-23-probe-results.md`에 전체화면 검증 표를 추가한다.

```bash
git add -A
git commit -m "fix: 표본 10종 전체화면 전환 100% 통과"
```

- [ ] **Step 5: 푸시**

```bash
git push
```

---

## 완료 후 상태

- `swift run restage probe --slot <slot> [--fullscreen]`으로 표본 10종의 배치와 전체화면을 언제든 재검증할 수 있다.
- `WindowEngine`의 네 동사가 실동작한다. 후속 사이클의 YAML 실행 루프는 이 프로토콜만 호출하면 된다.
- 멀티 디스플레이는 `DisplayProvider.primary()` 한 곳과 `WindowPlacer.apply` 전략 한 곳만 바꾸면 붙는다.

## 후속 사이클로 넘기는 것

전체 스펙 8절의 3~7단계다. 각각 별도 스펙과 계획으로 다룬다.

- YAML 파서와 화면 단위 실행 루프 (Yams 의존성 추가 검토 필요)
- 브라우저 탭 제어 (Apple Events 권한, AppleScript)
- 본격 CLI (`ws open`, `ws list`) — 이때 swift-argument-parser 도입 검토
- 메뉴바 UI와 편집 화면
- 단축키 바인딩
