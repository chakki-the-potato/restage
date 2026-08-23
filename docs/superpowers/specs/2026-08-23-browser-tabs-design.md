# restage 4단계 설계 — 브라우저 탭 제어

작성일: 2026-08-23
스코프: 전체 스펙 8절 작업 순서의 4단계
선행: `2026-08-23-workspace-runner-design.md` (3단계, PR #2)
상태: 승인됨

## 1. 목표

config의 `type: browser` 항목을 실행한다. 선언한 URL들을 브라우저 탭으로 열고, 필요하면 그 창도 배치한다.

완료 기준은 다음과 같다.

- config에 선언한 URL이 브라우저 탭으로 열린다.
- 같은 명령을 두 번 실행해도 창이 늘지 않고 탭이 중복되지 않는다.
- 이미 열려 있던 탭과 사용자가 따로 연 탭은 그대로 남는다.
- Apple Events 권한이 없으면 그 사실을 사유로 밝히고 나머지 항목은 계속 진행한다.

## 2. 스코프

**포함**

- Chrome과 Safari의 탭 열기
- `window: shared | separate` 처리
- 브라우저 창의 선택적 배치
- Apple Events 권한 오류 판별과 안내

**제외**

- 그 외 브라우저(Firefox, Arc 등). AppleScript 방언이 각기 달라 검증 없이 넣지 않는다.
- 탭 순서의 사후 보정. 아래 4절 참조.
- 워크스페이스 이름 레지스트리 (5단계), 메뉴바 UI (6단계), 단축키 (7단계)

## 3. 스키마 변경

`BrowserItem`에 두 필드를 추가한다.

```yaml
- type: browser
  app: chrome
  window: separate      # shared | separate. 기본값 separate
  slot: right-half      # 선택. 없으면 창 크기와 위치를 건드리지 않는다
  tabs:
    - https://example.com/a
    - https://example.com/b
```

`slot`을 선택 사항으로 둔 이유는 `window: shared`일 때 사용자 창을 멋대로 리사이즈하지 않기 위해서다. 앱 항목처럼 기본값을 `full`로 두면 빌려 쓰는 창의 크기를 바꾸게 된다.

## 4. 비파괴 원칙

**아무것도 닫지 않는다.** 이미 열린 탭, 사용자가 따로 연 탭, 다른 창 모두 그대로 둔다.

동작은 이렇다.

1. 대상 창을 찾는다.
2. 그 창에 이미 열려 있는 URL을 읽는다.
3. config에 있는데 없는 URL만 새 탭으로 추가한다.
4. 대상 창이 없으면 새로 만들고 config의 탭을 순서대로 연다.

이 결정의 대가는 **탭 순서가 첫 실행에만 정확하다**는 것이다. 나중에 추가되는 탭은 창 끝에 붙는다. 순서를 보장하려면 기존 탭을 닫고 재구성해야 하는데, 그러면 사용자가 열어둔 작업이 사라진다. 순서보다 사용자 작업을 지키는 쪽을 택했다.

이는 전체 스펙이 정한 "config에 없는 것은 건드리지 않는다"의 연장이다. 1단계에서 "config에 선언되지 않은 앱은 숨기거나 종료하지 않는다"고 정한 것과 같은 원칙을 탭에 적용한 것이다.

## 5. 대상 창 식별

`window` 값에 따라 다르다.

**`separate` (기본값)** — 워크스페이스 전용 창이다. config의 첫 URL을 첫 탭으로 가진 창을 찾는다. 없으면 새 창을 만든다.

첫 탭 URL을 표식으로 쓰는 이유는 브라우저가 창에 임의의 표식을 달 방법을 주지 않기 때문이다. 창 id는 브라우저를 재시작하면 무효가 되고, 창 제목은 탭 내용에 따라 바뀐다. 첫 탭 URL은 우리가 만든 창에서 안정적으로 유지된다.

한계는 명확하다. 첫 URL이 같은 워크스페이스가 둘이면 서로를 자기 창으로 착각한다. config를 쓰는 사람이 알아야 할 제약이므로 문서화한다.

**`shared`** — 사용자 창을 빌려 쓴다. 브라우저의 맨 앞 창을 대상으로 삼고, 없으면 새 창을 만든다.

## 6. URL 비교

"이미 열려 있는가"를 판정하려면 URL을 비교해야 하는데, 브라우저가 돌려주는 URL은 config에 적힌 것과 문자열이 다를 수 있다.

정규화 규칙은 다음과 같다.

- 스킴이 없으면 `https://`를 붙인다. config에 `example.com`이라고 적을 수 있다.
- 끝의 `/`를 제거한다. 브라우저는 `https://example.com`을 `https://example.com/`으로 돌려준다.
- 호스트를 소문자로 만든다.
- 쿼리와 프래그먼트는 그대로 둔다. 서로 다른 페이지일 수 있다.

이 정규화는 순수 함수이며 단위 테스트로 덮는다.

## 7. 모듈 경계

```
Sources/
  RestageKit/
    WorkspaceConfig.swift     (수정) BrowserItem에 window, slot 추가
    ScreenPlan.swift          (수정) TabPlan 추가
    URLNormalizer.swift       URL 정규화 (순수)
    WorkspaceResolver.swift   (수정) 브라우저 항목을 TabPlan으로 해석

  RestageKitDarwin/
    AppleScriptRunner.swift   NSAppleScript 실행과 권한 오류 판별
    BrowserDialect.swift      Chrome과 Safari의 AppleScript 문법 차이
    TabController.swift       탭 조회, 창 식별, 탭 추가
    WorkspaceRunner.swift     (수정) 브라우저 항목 처리
```

브라우저별 방언 차이는 `BrowserDialect` 한 곳에 가둔다. Safari는 `current tab`, Chrome은 `active tab`을 쓰는 등 어휘가 다르다. 새 브라우저를 추가하려면 이 파일만 손대면 된다.

`AppleScriptRunner`는 `NSAppleScript`로 스크립트를 실행하고 결과나 오류를 돌려준다. ScriptingBridge를 쓰지 않는 이유는 브라우저마다 생성 헤더가 필요하고, 우리가 쓰는 동작이 몇 개뿐이라 이득이 없기 때문이다.

## 8. 실행 흐름

브라우저 항목 하나에 대해 다음을 수행한다.

1. 앱을 실행하거나 기존 프로세스를 찾는다. 3단계의 `AppLauncher`를 그대로 쓴다.
2. 창이 나타날 때까지 기다린다. 3단계의 `WindowWaiter`를 쓴다.
3. 대상 창을 식별한다. `separate`면 첫 URL로, `shared`면 맨 앞 창으로.
4. 그 창의 현재 탭 URL 목록을 읽는다.
5. config에 있는데 없는 URL만 순서대로 새 탭으로 연다.
6. `slot`이 있으면 그 창을 배치한다.

`slot` 배치는 3단계의 `WindowPlacer`를 그대로 쓴다. 다만 배치 대상 창은 AX 창 목록의 첫 번째가 아니라 **탭 작업을 한 그 창**이어야 한다. AppleScript로 식별한 창과 AX 창을 맞춰야 하므로, 탭 작업 후 그 창을 맨 앞으로 올린 뒤 AX 창 목록의 첫 번째를 쓴다.

## 9. 실패 처리

3단계의 `OutcomeStatus`를 그대로 쓰고 사유만 브라우저 맥락으로 채운다.

| 상황 | 결과 | 사유 |
|---|---|---|
| 모든 탭이 이미 열려 있음 | `alreadySatisfied` | 이미 목표 상태 |
| 일부 탭을 새로 열었음 | `placed` | 열린 탭 수 |
| Apple Events 권한 없음 | `failed` | 자동화 권한 안내 |
| 지원하지 않는 브라우저 | `skipped` | 지원 목록 안내 |
| 앱 실행 실패 | `failed` | 3단계와 동일 |

Apple Events 권한 거부는 AppleScript 오류 `-1743`으로 온다. 이를 별도로 판별해 다음을 안내한다.

```
시스템 설정 > 개인정보 보호 및 보안 > 자동화에서
restage가 <브라우저>를 제어하도록 허용하세요.
```

3단계에서 화면 잠금을 별도로 판별한 것과 같은 이유다. 사유를 감추면 사용자가 고칠 수 없다.

권한 거부가 나도 다른 항목은 계속 진행한다.

## 10. 테스트

### 10.1 단위 테스트 (순수 함수)

`URLNormalizer`

- 스킴 없는 URL에 `https://` 추가
- 끝 슬래시 제거
- 호스트 소문자화
- 쿼리와 프래그먼트 보존
- 이미 정규형인 URL은 그대로

`BrowserDialect`

- Chrome과 Safari 각각에 대해 생성되는 AppleScript 문자열
- URL에 따옴표가 들어갔을 때 이스케이프

`WorkspaceResolver`

- 브라우저 항목이 `TabPlan`으로 해석되는지
- `window`와 `slot` 기본값
- 여러 브라우저 항목의 순서 보존

### 10.2 통합 검증

Safari로만 한다. Chrome은 사용자가 작업 중이다.

- 새 워크스페이스 → 전용 창에 탭이 순서대로 생성
- 2회 실행 → 창이 늘지 않고 탭도 중복되지 않음, `alreadySatisfied`
- 사용자가 탭을 추가한 뒤 재실행 → 추가한 탭이 그대로 남음
- config에 URL을 하나 추가한 뒤 재실행 → 그것만 새로 열림
- `window: shared` → 맨 앞 창에 추가
- `slot` 지정 시 창이 배치되는지

검증 중에는 `caffeinate`로 화면 잠금을 막는다. 3단계에서 확인했듯 잠긴 화면에서는 AX가 아무 창도 보지 못한다.

## 11. 알려진 한계

- 탭 순서는 첫 실행에만 정확하다. 이후 추가되는 탭은 창 끝에 붙는다.
- 첫 URL이 같은 워크스페이스가 둘이면 `separate` 모드에서 서로의 창을 자기 것으로 착각한다.
- Chrome과 Safari 외의 브라우저는 지원하지 않는다.
- Apple Events 권한은 대상 앱별로 최초 1회 팝업이 뜬다. 자동 승인할 방법은 없다.

## 12. 후속 사이클에 남기는 것

- 워크스페이스 이름 레지스트리와 `ws open <name>`, `ws list` (5단계)
- 메뉴바 UI (6단계), 단축키 (7단계)
- Space 지정. yabai 선택 의존.
