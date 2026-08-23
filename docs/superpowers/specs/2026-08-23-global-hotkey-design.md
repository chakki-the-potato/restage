# restage 7단계 설계 — 전역 단축키

작성일: 2026-08-23
스코프: 전체 스펙 8절 작업 순서의 7단계
선행: `2026-08-23-menubar-ui-design.md` (6단계)
상태: 승인됨

## 1. 목표

config의 `hotkey` 필드를 실제로 등록해 키 하나로 워크스페이스를 복원한다.

```yaml
workspace: dev
hotkey: "ctrl+alt+cmd+1"
```

완료 기준은 다음과 같다.

- 메뉴바가 떠 있는 동안 등록된 단축키가 동작한다.
- 잘못된 `hotkey` 문자열은 조용히 무시되지 않고 오류로 보고된다.
- 다른 앱과 충돌해 등록에 실패하면 그 워크스페이스만 건너뛰고 사유를 남긴다.
- 메뉴에 등록된 단축키가 표시된다.

## 2. Carbon을 쓰는 이유

`RegisterEventHotKey`(Carbon HIToolbox)로 등록한다. 이 머신에서 실제로 확인했다.

```
InstallEventHandler status=0
RegisterEventHotKey status=0 ref=true
>>> 단축키 눌림! id=1
```

**추가 권한이 필요 없다.** 접근성 권한과 무관하게 동작한다.

대안을 채택하지 않은 이유는 다음과 같다.

- `NSEvent.addGlobalMonitorForEvents`는 접근성 권한이 필요하고 이벤트를 소비하지 못한다. 다른 앱에도 키가 전달된다.
- `CGEvent` 탭은 접근성 권한이 필요하고 시스템 전체 키 입력을 가로채므로 과한 권한이다.

Carbon API가 오래됐지만 전역 단축키에는 여전히 표준 경로이며, 대체 공개 API가 없다.

### 2.1 합성 키 입력으로 발화한다

검증 중 확인한 사실이다. 합성 키 입력(`osascript key code`)으로도 Carbon 단축키가 발화했다.

3단계에서 Space 전환 단축키는 합성 입력으로 동작하지 않았다. 그것은 시스템이 처리하는 단축키라 합성 이벤트를 무시하기 때문이다. Carbon 단축키는 앱 수준 등록이라 일반 이벤트 경로를 탄다.

덕분에 **7단계는 자동 검증이 가능하다.** 6단계 메뉴바처럼 사람이 클릭해야만 확인되는 부분이 없다.

## 3. 유효 범위

단축키는 메뉴바가 떠 있는 동안만 유효하다. `restage menubar`가 실행 중이어야 한다.

CLI(`restage open dev`)는 단축키를 등록하지 않는다. 명령이 끝나면 프로세스가 종료되므로 등록해도 의미가 없다.

## 4. 문자열 형식

```
ctrl+alt+cmd+1
cmd+shift+d
opt+f5
```

**수식키** — 순서와 대소문자를 가리지 않는다.

| 표기 | 의미 |
|---|---|
| `cmd`, `command` | Command |
| `ctrl`, `control` | Control |
| `alt`, `opt`, `option` | Option |
| `shift` | Shift |

**키** — 마지막 성분이다.

- `0`~`9`, `a`~`z`
- `f1`~`f12`
- `space`, `return`, `tab`, `escape`

수식키가 하나도 없으면 오류다. 수식키 없는 전역 단축키는 일반 타이핑을 가로채므로 허용하지 않는다.

## 5. 계층 분리

파싱 결과는 OS에 의존하지 않는 형태로 표현한다. Carbon 상수는 `RestageKitDarwin` 안쪽에만 존재한다.

```swift
public struct HotkeySpec: Equatable, Sendable {
    public let modifiers: Set<HotkeyModifier>
    /// 정규화된 키 이름. "1", "a", "f1", "space" 등.
    public let key: String

    public static func parse(_ raw: String) throws -> HotkeySpec
    public var displayString: String   // "⌃⌥⌘1"
}

public enum HotkeyModifier: String, Sendable, CaseIterable {
    case command, control, option, shift
}
```

`displayString`은 메뉴에 표시할 기호 문자열이다. 순서는 macOS 관례를 따라 `⌃⌥⇧⌘`이다.

## 6. 등록과 충돌

메뉴바 시작 시 등록된 워크스페이스를 순회하며 `hotkey`가 있는 것만 등록한다.

등록 결과는 셋으로 나뉜다.

| 결과 | 의미 |
|---|---|
| 등록됨 | 메뉴 항목 오른쪽에 단축키 기호를 표시한다 |
| 형식 오류 | config를 고쳐야 한다. 메뉴 툴팁에 사유를 넣는다 |
| 충돌 | 다른 앱이 이미 쓰는 조합이다. 툴팁에 사유를 넣는다 |

**한 워크스페이스의 등록 실패가 나머지를 막지 않는다.** 1~6단계에서 지켜온 원칙 그대로다.

같은 단축키를 여러 워크스페이스가 쓰면 먼저 나오는 것만 등록되고 나머지는 충돌로 보고한다.

## 7. config 변경 반영

메뉴는 열 때마다 다시 만들지만 단축키는 그럴 수 없다. 등록은 프로세스 수명에 묶인 자원이기 때문이다.

메뉴를 열 때 config 목록을 다시 읽으므로, 그 시점에 **등록 상태와 config를 대조해 차이가 있으면 재등록**한다. 파일을 고치고 메뉴를 한 번 열면 반영된다.

전체를 해제하고 다시 등록하는 방식으로 한다. 워크스페이스가 수십 개를 넘지 않으므로 차이를 계산할 이유가 없다.

## 8. 모듈 경계

```
Sources/
  RestageKit/
    HotkeySpec.swift          문자열 파싱과 표시 문자열 (순수)
    ConfigError.swift         (수정) invalidHotkey 추가

  restage/
    HotkeyRegistry.swift      Carbon 등록·해제, 콜백 전달
    MenuBarController.swift   (수정) 시작 시 등록, 메뉴에 표시
```

`RestageKitDarwin`은 수정하지 않는다. 단축키는 메뉴바에만 필요하고 엔진과 무관하다.

`HotkeyRegistry`를 `restage` 타겟에 두는 이유는 메뉴바 전용이기 때문이다. 라이브러리 계층에 올리면 CLI도 링크하게 되는데 CLI는 쓰지 않는다.

## 9. 검증

### 9.1 단위 테스트

`HotkeySpec.parse`

- 수식키 순서와 대소문자 무관
- 별칭(`cmd`/`command`, `alt`/`opt`/`option`)
- 숫자, 문자, 함수키, 특수키
- 수식키 없음 → 오류
- 알 수 없는 수식키 → 오류
- 알 수 없는 키 → 오류
- 빈 문자열 → 오류

`displayString`

- `ctrl+alt+cmd+1` → `⌃⌥⌘1`
- 순서가 입력과 달라도 `⌃⌥⇧⌘` 순으로 정렬

### 9.2 통합 검증

메뉴바를 띄우고 합성 키 입력으로 발화를 확인한다. 사람 손이 필요 없다.

- 등록 성공 여부
- 합성 키 입력 후 워크스페이스가 실행되는지
- 충돌하는 조합을 두 워크스페이스에 넣었을 때 하나만 등록되고 다른 하나에 사유가 붙는지
- 잘못된 형식이 메뉴 툴팁에 드러나는지

## 10. 후속 사이클에 남기는 것

- 편집 화면. 앱 피커, slot 선택, 드래그 정렬.
- 앱 번들, 로그인 시 자동 실행, 공증, Homebrew cask 배포.
- 창이 여러 개인 앱에서 어느 창을 옮길지 지정하는 방법.
- Space 지정. yabai 선택 의존.
