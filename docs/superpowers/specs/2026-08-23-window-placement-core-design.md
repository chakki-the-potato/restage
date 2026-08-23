# restage 1단계 설계 — 창 배치 엔진 코어

작성일: 2026-08-23
스코프: 전체 스펙 8절 작업 순서의 1~2단계
상태: 승인됨

> **이후 변경 (2026-08-24)**
> `AppRegistry`는 삭제되었고 `InstalledApps`가 그 자리를 대신한다. 고정 매핑 대신 설치된 앱을
> 검색해 이름을 해석한다. `probeSample`과 `protected`도 없앴다. 이유와 측정값은
> [dynamic-apps-and-new-command-results](../plans/2026-08-24-dynamic-apps-and-new-command-results.md)에 있다.
> `bundle ID는 한 파일에만 존재한다`는 규칙은 그대로이며, 그 파일이 `InstalledApps.swift`로 옮겨졌다.

## 1. 목표

접근성 권한 1회 승인으로, 지정한 앱을 지정한 slot에 배치하고 네이티브 전체화면으로 전환하는 엔진 코어를 만든다.

완료 기준은 두 단계로 나뉜다.

- 1단계: 검증 표본 9종 × (콜드 스타트, 웜 스타트) × `left-half` = 18케이스가 전부 `PASS` 또는 사유가 명시된 `CONSTRAINED`.
- 2단계: 같은 9종에 대해 `fullscreen` 18케이스 추가 통과.

이 범위에는 YAML 파서, 화면 단위 실행 루프, 브라우저 탭 제어, 메뉴바 UI, 단축키가 **포함되지 않는다**. 그것들은 후속 사이클에서 별도 스펙으로 다룬다.

## 2. 기술 선택

### 2.1 언어: Swift 단일

결정 근거는 TCC 권한 모델이다. 접근성 권한은 서명된 바이너리 단위로 부여되므로, 바이너리가 하나면 승인도 하나이고 서명이 유지되는 한 업데이트 후에도 승인이 살아 있다. Node 런타임이나 별도 helper 프로세스를 끼우면 권한 주체가 갈라지고, 재서명·업데이트마다 승인이 초기화된다. 접근성 권한이 없으면 이 도구는 아무것도 못 하므로 여기서 새는 것을 감당할 수 없다.

부수 근거는 다음과 같다.

- 코어인 `AXUIElement`, `NSWorkspace`는 우회로가 없는 Cocoa API다. 어떤 언어를 골라도 결국 이것을 호출하며 Swift는 브리지가 0겹이다.
- 공증 및 Homebrew cask 배포가 전체 스펙 7절에 이미 정해져 있고, 단일 Swift 바이너리가 그 표준 경로다.
- 후속 사이클의 메뉴바 UI를 SwiftUI `MenuBarExtra`로 같은 타겟 안에서 처리할 수 있다.

Rust는 accessibility 크레이트가 미성숙해 결국 `CFTypeRef`를 unsafe로 직접 다루게 되며, Swift와 하는 일이 같으면서 마찰만 크므로 채택하지 않는다.

### 2.2 권한 모델 정리

혼동하기 쉬운 지점이라 명시한다.

- **접근성 권한**: restage 바이너리 하나에만 부여한다. 제어당하는 앱은 아무 승인도 하지 않으며, 등록 목록이라는 개념 자체가 없다. 승인된 순간부터 설치된 모든 앱의 창을 조작할 수 있다. 1~2단계에 필요한 권한은 이것 하나뿐이다.
- **앱 실행**: `NSWorkspace.openApplication`은 권한이 필요 없다.
- **Apple Events**: 대상 앱별로 최초 1회 승인 팝업이 뜬다. 브라우저 탭 제어(4단계)에서만 발생하며 이번 스코프에 해당하지 않는다.

### 2.3 배포 타겟

최소 지원 버전은 macOS 13(Ventura)이다. `Duration` 타입과 `MenuBarExtra`가 13부터 제공되며, 후자는 후속 사이클의 메뉴바 UI에 필요하다. 더 낮추면 시간 표현을 `TimeInterval`로 되돌려야 하고 얻는 것이 없다.

## 3. 모듈 경계

Swift Package로 구성한다. OS 의존 개념이 상위 계층으로 새지 않도록 3계층으로 자른다.

```
Package.swift
Sources/
  restage/                    실행 진입점
    main.swift
    ProbeCommand.swift        probe 서브커맨드 정의 및 실행
    ProbeReport.swift         결과 표 조립 및 출력
  RestageKit/                 OS 비의존 인터페이스와 순수 로직
    WindowEngine.swift        protocol 정의
    Slot.swift                slot enum과 frame 계산
    PlacementResult.swift     결과 값 타입
  RestageKitDarwin/           macOS 구현
    AXWindowEngine.swift      WindowEngine 구현. 하위 컴포넌트 조립만 담당
    AppLauncher.swift         앱 실행과 기존 프로세스 탐지
    WindowWaiter.swift        waitForWindow 폴링
    WindowPlacer.swift        place와 수렴 루프
    FullScreenController.swift 전체화면 진입 및 해제
    AXWindow.swift            AXUIElement 속성 접근 래퍼
    Polling.swift             공용 폴링 유틸리티
    AppRegistry.swift         논리 앱 이름 → bundle ID 해석
    AccessibilityPermission.swift 권한 확인과 온보딩 안내
Tests/
  RestageKitTests/
    SlotFrameTests.swift      Slot.frame 좌표 계산 검증
```

경계 규칙은 두 가지다.

- `AXUIElement` 직접 호출은 `AXWindow.swift` 안에만 존재한다. 다른 파일은 `AXWindow`가 노출하는 타입 안전한 접근자만 쓴다.
- bundle ID 문자열은 `AppRegistry.swift` 안에만 존재한다. 상위 계층은 `AppID`(논리 이름)만 다룬다.

이는 전체 스펙 1절의 "OS 의존 개념이 스키마/UI로 새어나가지 않게 한다"를 파일 경계로 강제한 것이다.

## 4. 인터페이스

`RestageKit/WindowEngine.swift`에 정의한다. 이번 스코프에서 구현하는 것은 앞 네 개이며, 나머지는 후속 사이클에서 추가한다.

```swift
protocol WindowEngine {
    func launch(_ app: AppID) throws -> ProcessHandle
    func waitForWindow(_ handle: ProcessHandle, timeout: Duration) throws -> WindowRef
    func place(_ window: WindowRef, slot: Slot, display: DisplayRef) -> PlacementResult
    func fullscreen(_ window: WindowRef) -> PlacementResult
}
```

`AppID`는 논리 앱 이름을 감싼 값 타입, `ProcessHandle`은 pid 래퍼, `WindowRef`와 `DisplayRef`는 각각 창과 디스플레이의 불투명 참조다. 넷 모두 `RestageKit`에 정의하며 내부에 OS 고유 타입을 노출하지 않는다.

`place`와 `fullscreen`은 예외를 던지지 않고 결과 값을 반환한다. 후속 사이클에서 "타임아웃 시 해당 항목을 건너뛰고 나머지를 계속 진행한 뒤 실패 목록을 보고" 하는 동작으로 그대로 확장하기 위함이다.

### 4.1 결과 타입

```swift
enum PlacementResult {
    case ok(actual: CGRect, attempts: Int, elapsed: Duration)
    case constrained(actual: CGRect, expected: CGRect, minSize: CGSize, reason: String)
    case failed(expected: CGRect, actual: CGRect?, reason: String)
}
```

`constrained`가 별도 상태인 이유는 다음과 같다. 일부 앱은 `AXMinSize` 제약 때문에 좁은 slot에 물리적으로 들어갈 수 없다. 이를 `failed`로 뭉뚱그리면 고칠 수 없는 대상을 버그로 오인하고 붙들게 된다. 최소 크기 제약이 원인임이 확인된 경우에만 `constrained`로 분류하며, 이는 완료 기준상 통과로 취급한다.

경고 상황도 실패와 구분한다. 대상 창이 다른 Space에 있으면 배치 자체는 성공하지만 화면에 보이지 않는다. Space 이동은 전체 스펙에서 제외한 영역이므로 손댈 수 없다. 이 경우 `ok`로 반환하되 리포트에 경고를 표기한다.

## 5. 실행 흐름

```
AccessibilityPermission.ensure()
  → AppRegistry.resolve(AppID) → bundle ID
  → AppLauncher.launch(bundleID) → ProcessHandle
  → WindowWaiter.wait(handle, timeout: 5s) → WindowRef
  → Slot.frame(slot, in: display.visibleFrame) → CGRect (AX 좌표계)
  → WindowPlacer.place(window, target: rect) → PlacementResult
  → [2단계] FullScreenController.enter(window) → PlacementResult
```

### 5.1 AppLauncher

`NSWorkspace.shared.runningApplications`에서 bundle ID가 일치하는 프로세스를 먼저 찾는다. 있으면 그 pid를 반환한다(웜 스타트). 없으면 `NSWorkspace.openApplication`으로 실행한다(콜드 스타트). 이미 실행 중인 앱을 중복 실행하지 않고 기존 창을 재배치하는 것이 기본 동작이다.

### 5.2 WindowWaiter

고정 sleep을 쓰지 않는다. 다음 조건을 모두 만족할 때까지 폴링한다.

- 해당 프로세스의 AX 트리에 window가 존재한다.
- `AXRole == kAXWindowRole`이다. 스플래시 화면과 모달을 배제한다.
- `AXSize`의 너비와 높이가 모두 0보다 크다.

추가로 두 가지 상태를 정리한 뒤 조건을 재확인한다.

- `AXMinimized`가 true이면 false로 설정한다. 최소화된 창은 위치와 크기를 쓸 수 없다.
- `AXFullScreen`이 true이고 목표가 desktop 배치이면 false로 설정한다. 전환 애니메이션이 있으므로 크기가 안정될 때까지 폴링한다.

반환값은 AX 창 목록의 첫 번째 요소다. macOS는 이 목록을 최근 활성 순으로 제공하므로, 창이 여러 개일 때 사용자가 마지막으로 보던 창이 선택된다. 나머지 창은 건드리지 않는다.

타임아웃은 5초다. 초과 시 해당 항목을 실패로 기록하고 다음으로 진행한다.

### 5.3 Slot과 좌표계

`Slot.frame(_ slot: Slot, in visibleFrame: CGRect) -> CGRect`는 순수 함수다.

입력은 `NSScreen.visibleFrame`이다. 메뉴바와 Dock이 차지하는 영역이 제외된 사각형이므로, 배치된 창이 Dock에 가리지 않는다.

좌표계 변환이 이 함수의 핵심 책임이다. `NSScreen`은 bottom-left 원점에 y가 위로 증가하고, AX는 주 디스플레이 기준 top-left 원점에 y가 아래로 증가한다. 변환식은 이 함수 안에만 두고 다른 어느 곳에서도 반복하지 않는다.

이번 스코프에서 구현하는 slot은 `full`, `left-half`, `right-half`, `top-half`, `bottom-half`, `q1`~`q4`, `centered`다. 홀수 픽셀 분할 시 왼쪽 및 위쪽 영역이 남은 1pt를 가져간다.

디스플레이는 주 디스플레이만 다룬다. 멀티 디스플레이 선택 로직은 후속 사이클에서 추가한다.

### 5.4 WindowPlacer 수렴 루프

고정 대기 시간을 쓰지 않는다는 원칙을 검증 단계에도 동일하게 적용한다.

1. `AXPosition`을 설정한다.
2. `AXSize`를 설정한다.
3. 25ms 간격으로 실제 `AXPosition`과 `AXSize`를 재조회한다.
4. 연속 2회 동일한 값이 나오면 안정된 것으로 판정한다.
5. 안정값이 목표와 ±2pt 이내면 `ok`를 반환한다.
6. 벗어나면 1로 돌아가 재적용한다. 최대 3회 시도, 전체 3초를 상한으로 둔다.
7. 상한 도달 시 `AXMinSize`를 조회한다. 목표 크기가 최소 크기보다 작아서 생긴 차이면 `constrained`, 아니면 `failed`를 반환한다.

Electron 기반 앱은 set이 성공한 뒤 자기 렌더러가 뒤늦게 크기를 되돌린다. 안정 판정을 "연속 2회 동일"로 둔 것은 이 되돌림이 끝난 시점을 잡기 위해서다. 빠른 앱은 50ms 안에 종료되고 느린 앱만 기다린다.

적용 순서는 교체 가능한 전략으로 둔다. 멀티 디스플레이를 다루게 되면 화면 경계를 넘을 때 clamp를 피하기 위해 `position → size → position` 3단 적용이 필요해지는데, 그때 전략만 갈아끼우면 되도록 한다. 이번 스코프에서는 검증할 수 없는 경로이므로 구현하지 않는다.

### 5.5 FullScreenController

`AXFullScreen` 속성을 true로 설정한다. 실패하면 `AXFullScreenButton`에 `AXPress` 액션을 보낸다. 두 경로 모두 전환 애니메이션이 있으므로 `AXFullScreen`이 true가 되고 창 크기가 안정될 때까지 폴링한다. 타임아웃은 3초다.

## 6. probe 하네스

검증은 XCTest가 아니라 배포 바이너리 자신의 서브커맨드로 수행한다. XCTest는 `xctest` 러너 프로세스가 실행하는데 이 바이너리는 빌드마다 경로와 서명이 바뀌어 TCC 승인이 계속 무효화되고, 결국 배포물과 다른 조건에서 검증하게 되기 때문이다. probe를 본체 바이너리에 두면 권한이 한 번만 필요하고, 검증 코드가 실제 배포 경로와 동일한 코드를 탄다.

```
restage probe --slot left-half                    표본 9종 전부, 콜드와 웜 각각
restage probe --app notion --slot q1              단일 앱
restage probe --slot left-half --fullscreen       배치 후 전체화면까지
```

출력 항목은 앱 이름, 스타트 종류(콜드/웜), 결과(PASS/CONSTRAINED/FAIL/WARN), 기대 좌표, 실측 좌표, 시도 횟수, 소요 시간이다. 마지막에 집계 요약을 붙인다.

콜드 스타트 케이스는 대상 앱이 실행 중이면 먼저 종료하고 시작한다. 웜 스타트 케이스는 콜드 케이스 직후 같은 앱에 대해 다시 실행하여, 중복 실행 없이 기존 창이 재배치되는지 확인한다.

## 7. 검증 표본

실패 유형이 서로 다른 군을 덮도록 선정했다. 권한 등록 목록이 아니라 테스트 대상이며, 여기에 없는 앱도 동일하게 동작한다.

| 앱 | bundle ID | 검증 의도 |
|---|---|---|
| Safari | `com.apple.Safari` | 표준 Cocoa 기준선 |
| iTerm | `com.googlecode.iterm2` | 터미널, 문자 그리드 단위 리사이즈 |
| Xcode | `com.apple.dt.Xcode` | 느린 기동, waitForWindow 타임아웃 경계 |
| IINA | `com.colliderli.iina` | 미디어 앱, 종횡비 제약 |
| Google Chrome | `com.google.Chrome` | Chromium, Electron과 다른 창 관리 |
| Discord | `com.hnc.Discord` | Electron, 최소 너비 제약 (CONSTRAINED 후보) |
| Notion | `notion.id` | Electron |
| Claude | `com.anthropic.claudefordesktop` | Electron |
| KakaoTalk | `com.kakao.KakaoTalkMac` | 비표준 창 구조, AXRole 필터링 검증 |

`AppRegistry`는 이 매핑을 보유하며, 논리 이름(`safari`, `chrome` 등)으로 조회한다.

Cursor는 매핑에는 두되 표본에서는 제외한다. probe의 콜드 스타트가 대상 앱을 종료하는데, 이 저장소의 개발이 Cursor 안에서 이뤄지므로 자기 자신을 죽이게 된다. Electron 자가 리사이즈는 Discord, Notion, Claude 3종이 덮는다.

측정 중에는 Rectangle을 비활성화한다. 창 관리자가 배치 직후 창을 다시 잡으면 측정 결과가 오염된다.

## 8. 테스트 전략

`Slot.frame`만 단위 테스트로 덮는다. 순수 함수이며 경계 조건에서 실수하기 쉽기 때문이다. 검증 항목은 다음과 같다.

- 각 slot이 `visibleFrame`을 정확히 분할하는지
- 홀수 너비 및 높이 분할 시 나머지 픽셀 배분
- bottom-left에서 top-left로의 좌표 변환
- Dock 위치(하단, 좌측, 우측)에 따라 달라지는 `visibleFrame` 입력

그 외 모든 검증은 probe 하네스가 실제 앱으로 수행한다. mock을 쓰지 않는다. 이 프로젝트에서 검증할 가치가 있는 것은 실제 앱의 실제 창 동작이며, mock한 AX 트리는 아무것도 증명하지 못한다.

## 9. 권한 온보딩

probe 첫 실행 시 `AXIsProcessTrustedWithOptions`로 접근성 권한을 확인한다. 미승인이면 시스템 프롬프트를 띄우고, 시스템 설정 딥링크(`x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`)를 출력한 뒤 종료한다. 권한 없이 진행해 알 수 없는 실패를 내지 않는다.

## 10. 후속 사이클에 정해둔 방향

이번 스코프에서 구현하지 않지만 설계 방향을 확정한 사항이다.

- config에 선언되지 않은 앱은 건드리지 않는다. 숨기거나 종료하지 않으며, 스키마에 관련 옵션을 두지 않는다. 비가역 동작이 없어야 실행 부담이 없고 실수로 돌려도 잃는 것이 없다.
- 창이 여러 개인 앱은 가장 최근 활성 창 하나만 배치한다. 새 창을 만들지 않고 나머지 창도 건드리지 않는다.
- 멀티 디스플레이 지원 시 `WindowPlacer`의 적용 순서 전략을 3단 적용으로 교체한다.
