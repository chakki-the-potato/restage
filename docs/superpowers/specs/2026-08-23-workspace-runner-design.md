# restage 3단계 설계 — YAML 파서와 워크스페이스 실행 루프

작성일: 2026-08-23
스코프: 전체 스펙 8절 작업 순서의 3단계
선행: `2026-08-23-window-placement-core-design.md` (1~2단계, PR #1)
상태: 승인됨

## 1. 목표

선언형 YAML 파일 하나로 워크스페이스를 복원한다. 1단계에서 만든 엔진을 화면 단위 실행 루프로 조립하고, 멀티 디스플레이를 지원한다.

완료 기준은 다음과 같다.

- 실제 config 파일로 `restage open <경로>`를 실행해 선언한 앱들이 지정한 화면의 지정한 slot에 배치된다.
- 같은 명령을 두 번 연속 실행해도 결과가 동일하다.
- 한 항목이 실패해도 나머지가 완료되고, 마지막에 실패 목록이 사유와 함께 보고된다.

## 2. 스코프

**포함**

- YAML 파싱과 검증
- 워크스페이스 실행 루프 (화면 단위)
- 멀티 디스플레이 지원
- `restage open <경로>` 진입점

**제외**

- 브라우저 탭 제어 (4단계)
- 워크스페이스 이름 레지스트리와 `ws open <name>` (5단계)
- 메뉴바 UI (6단계)
- 단축키 바인딩 (7단계)

`hotkey` 필드와 `type: browser` 항목은 **파싱은 하되 실행 시 미구현 오류를 낸다.** 전체 스펙대로 작성한 config가 "알 수 없는 키"로 죽지 않게 하면서, 동시에 조용히 무시되지도 않게 하기 위함이다.

## 3. 스키마

전체 스펙에 정의된 스키마를 여기 기록한다. 지금까지 이 스키마는 대화에만 존재했고 저장소에 없었다.

```yaml
workspace: dev
hotkey: "ctrl+alt+cmd+1"
screens:
  - id: code
    display: builtin
    mode: fullscreen
    anchor: vscode
    items:
      - {type: app, app: vscode,   slot: left-half}
      - {type: app, app: terminal, slot: right-half}

  - id: research
    display: any
    mode: desktop
    items:
      - type: browser
        app: chrome
        window: shared
        tabs:
          - https://example.com/a
          - https://example.com/b
```

필드별 규칙이다.

| 필드 | 필수 | 값 |
|---|---|---|
| `workspace` | 예 | 워크스페이스 이름 |
| `hotkey` | 아니오 | 7단계용. 파싱만 하고 사용하지 않는다 |
| `screens` | 예 | 화면 배열. 비어 있으면 오류 |
| `screens[].id` | 예 | 화면 식별자. 보고서에 쓰인다 |
| `screens[].display` | 아니오 | `builtin` / `external-N` / `any`. 기본값 `any` |
| `screens[].mode` | 아니오 | `fullscreen` / `desktop`. 기본값 `desktop` |
| `screens[].anchor` | 아니오 | 이 화면 처리가 끝날 때 포커스할 앱 이름. 그 화면의 items에 있어야 한다 |
| `screens[].items` | 예 | 항목 배열. 비어 있으면 오류 |

항목의 `type`은 `app` 또는 `browser`다. `app` 항목은 `app`(논리 이름)과 `slot`을 갖는다. `slot`의 기본값은 `full`이다.

`order` 필드는 없다. 배열 순서가 곧 순서다. 전체 스펙 3절이 "사용자에게 숫자 입력을 받지 않는다"고 정한 대로다.

## 4. 아키텍처 — 선언적 조정

전체 스펙 5절은 명령형 순차 실행으로 적혀 있다. 이 설계는 목표 상태를 계산하고 현재 상태와 비교하는 구조로 바꾼다.

이유는 멱등성이다. 1~2단계 검증에서 **전체화면이 편도**임이 확인됐다. AX로 앱을 전체화면에 넣을 수는 있어도 뺄 수 없다. 전체화면 앱은 전용 Space로 옮겨지는데 화면이 그 Space로 전환되지 않아 창에 도달할 방법이 없기 때문이다.

명령형으로 짜면 두 번째 실행에서 이미 전체화면인 앱의 창을 찾지 못해 실패로 보고한다. 전체 스펙 9절의 "동일 워크스페이스 2회 연속 실행 → 결과 동일" 요구와 정면으로 충돌한다.

목표를 동작이 아니라 상태로 보면 이 문제가 사라진다. 이미 목표 상태인 항목은 건드리지 않고 달성으로 처리한다.

파이프라인은 넷이다.

```
YAML  →  WorkspaceConfig   파싱·검증          (순수)
      →  [ScreenPlan]      해석: 목표 좌표 계산 (순수)
      →  [ItemOutcome]     조정: 현재 상태와 비교 후 실행
      →  RunReport         집계·출력
```

앞의 두 단계가 순수 함수다. 파싱·검증과 좌표 해석은 실제 앱 없이 테스트할 수 있다. 1단계에서는 `SlotGeometry`만 단위 테스트로 덮을 수 있었으나, 이번에는 파싱·검증·해석 전체가 검증 가능하다.

## 5. 모듈 경계

```
Sources/
  RestageKit/
    WorkspaceConfig.swift      Codable 스키마 타입
    ConfigLoader.swift         파일 읽기와 Yams 디코딩
    ConfigError.swift          파싱·검증 오류
    ScreenPlan.swift           해석된 목표 값 타입
    WorkspaceResolver.swift    config + [DisplayInfo] → [ScreenPlan]

  RestageKitDarwin/
    DisplayCatalog.swift       화면 열거와 display 식별자 매핑
    CurrentState.swift         현재 창 상태 조회
    WorkspaceRunner.swift      조정 루프
    WindowPlacer.swift         (수정) 멀티 디스플레이 3단 적용

  restage/
    OpenCommand.swift          restage open <경로>
    RunReport.swift            결과 표
```

기존 파일 중 손대는 것은 둘뿐이다.

- `WindowPlacer` — 적용 순서를 3단으로 교체. 1단계에서 교체 지점으로 남겨둔 곳이다.
- `DisplayProvider` — `DisplayCatalog`로 확장하고 기존 `primary()`는 유지한다. probe가 계속 쓴다.

`Yams` 의존성은 `RestageKit`에만 붙는다. `RestageKitDarwin`과 `restage`는 YAML을 모른다.

## 6. 멀티 디스플레이

### 6.1 display 식별자 해석

- `builtin` — `NSScreen.screens.first`. 메뉴바를 가진 주 디스플레이다.
- `external-N` — 주 디스플레이를 제외한 나머지를 프레임 원점 기준으로 정렬한 뒤 N번째(1부터). 정렬 없이 `NSScreen.screens`의 배열 순서를 쓰면 재부팅이나 연결 순서에 따라 달라진다.
- `any` — 주 디스플레이.

정렬 기준은 프레임 원점의 x, 같으면 y 오름차순이다.

`external-0`이나 음수는 검증 단계에서 오류다. 두 화면이 같은 디스플레이를 가리키는 것은 허용한다. 그 경우 항목들이 같은 화면에 함께 배치되며, 서로 겹치는 slot을 쓰면 나중 것이 앞에 온다.

해당 디스플레이가 없으면 그 화면 전체를 건너뛰고 사유를 보고한다. 나머지 화면은 계속 진행한다.

### 6.2 배치 적용 순서

`WindowPlacer`의 적용을 `position → size → position` 3단으로 바꾼다.

첫 position으로 목표 화면에 진입시키고, size를 적용한 뒤, size 적용 중 밀린 position을 다시 맞춘다. 크기부터 적용하면 창이 아직 원래 화면에 있어 그 화면 경계로 clamp된다.

단일 디스플레이에서는 3단 적용이 2단과 동일한 결과를 낸다. 1단계 검증 결과가 회귀하지 않아야 한다.

## 7. 실행 흐름

화면 단위로 순차 처리한다.

1. `display`를 실제 디스플레이로 해석한다. 없으면 화면 전체를 건너뛴다.
2. 해당 화면의 앱을 **먼저 전부 실행**한다. 전체 스펙 5절이 정한 순서다. 실행과 창 대기를 분리하면 여러 앱의 기동 시간이 겹쳐 전체 소요가 준다.
3. 항목마다 창을 기다리고 현재 상태를 읽는다.
4. 목표와 비교해 다른 것만 배치한다.
5. `mode: fullscreen`이면 전체화면으로 전환한다. 이미 전체화면이면 건너뛴다.
6. 그 화면에 `anchor`가 있으면 해당 앱에 포커스한다.
7. 다음 화면으로 넘어간다.
8. 전부 끝난 뒤 첫 화면의 `anchor`에 다시 포커스한다. `anchor`가 없으면 아무것도 하지 않는다.

`anchor`가 두 번 적용되는 것은 의도한 동작이다. 화면별 `anchor`는 그 화면 안에서 어느 앱이 앞에 오는지를 정하고, 마지막 포커스는 작업이 끝났을 때 사용자가 어디를 보게 될지를 정한다. 전체 스펙 5절이 정한 순서다.

### 7.1 목표 상태 판정

배치 목표 달성 여부는 창의 현재 사각형이 목표와 ±2pt 이내인지로 판정한다. 1단계의 tolerance와 같다.

전체화면 목표 달성 여부는 AX로 판정할 수 없다. 전체화면 앱의 창은 다른 Space에 있어 `AXWindows`가 비어 있기 때문이다. 대신 `CGWindowListCopyWindowInfo(.optionAll)`로 해당 프로세스의 창을 조회해, 화면 전체 크기에 해당하는 창이 있으면 달성으로 본다.

이 판정은 1~2단계에서 이미 검증한 사실에 기반한다. `CGWindowList`는 Space와 무관하게 창을 열거하며, AX 결과와 대조하면 "창이 없다"와 "다른 Space에 있다"를 구별할 수 있다.

## 8. 실패 처리

한 항목의 실패가 나머지를 막지 않는다. 각 항목은 결과 값을 반환하고, 루프는 끝까지 진행한 뒤 실패 목록을 사유와 함께 보고한다.

결과는 다음으로 구분한다.

| 결과 | 의미 |
|---|---|
| `placed` | 배치했다 |
| `alreadySatisfied` | 이미 목표 상태여서 건드리지 않았다 |
| `constrained` | 앱이 막았다. 최소 크기, 크기 고정, 전체화면 미지원 |
| `unreachable` | 창이 다른 Space에 있어 접근할 수 없다 |
| `failed` | 그 외 실패. 앱 미설치, 실행 실패, 창 미등장 |
| `skipped` | 미구현 기능. `type: browser` |

`alreadySatisfied`와 `constrained`는 성공으로 집계한다. 앞의 것은 목표가 달성된 상태이고, 뒤의 것은 고칠 수 없는 앱 동작이다.

`unreachable`을 별도 상태로 둔 이유는 1~2단계에서 이 경우가 "창이 뜨지 않았습니다"로 보고되어 원인을 감췄기 때문이다.

## 9. 테스트

### 9.1 단위 테스트 (순수 함수)

이번 사이클은 로직의 상당 부분이 실제 앱 없이 검증 가능하다.

`ConfigLoader`

- 유효한 config 디코딩
- 필수 필드 누락 시 오류와 그 메시지
- 잘못된 `slot`, `display`, `mode` 값
- `screens`나 `items`가 빈 배열
- `type: browser` 항목이 파싱은 되고 실행 대상에서 제외되는지
- 기본값 적용 (`display: any`, `mode: desktop`, `slot: full`)

`WorkspaceResolver`

- 디스플레이 1대와 2대 각각에서 `builtin` / `external-1` / `any` 해석
- 존재하지 않는 `external-2` 요청 시 화면 건너뜀
- `anchor`가 그 화면의 items에 없을 때 검증 오류
- 해석된 목표 좌표가 `SlotGeometry` 결과와 일치

목표 상태 비교

- 현재 사각형이 목표와 같으면 `alreadySatisfied`
- tolerance 경계값 (±2pt)

### 9.2 통합 검증

실제 config 파일로 `restage open`을 실행한다.

**전체화면 검증은 파괴적이다.** 앱을 전체화면으로 만들면 되돌릴 수 없고 Space가 남는다. 따라서 통합 검증은 `mode: desktop` 위주로 구성하고, 전체화면은 앱 하나로 1회만 확인한다.

검증 항목은 다음과 같다.

- 2화면 config: 내장 디스플레이에 2개 앱 좌우 분할, 외장 디스플레이에 1개 앱 전체
- 동일 명령 2회 연속 실행 시 결과 동일 (두 번째는 전부 `alreadySatisfied`)
- 존재하지 않는 앱을 포함한 config에서 나머지가 완료되고 그 항목만 실패 보고
- 연결되지 않은 `external-2`를 지정한 화면이 건너뛰어지고 나머지 화면이 완료

검증 중에는 화면 잠금을 막는다. 1~2단계에서 잠긴 화면이 모든 항목을 실패로 만들면서 원인을 감춘 사례가 있었다.

```
caffeinate -d -i -t 1200
```

## 10. 의존성

`Yams`를 추가한다. Swift 진영의 사실상 표준 YAML 라이브러리이며 MIT 라이선스다. libYAML을 감싸고 `Codable`을 지원한다.

직접 파서를 쓰지 않는 이유는 YAML이 보기보다 복잡해서다. 들여쓰기, 인용부호, 중첩 리스트 처리에서 사용자 config가 조용히 잘못 해석될 위험이 있고, 그것은 이 프로젝트의 본질과 무관한 곳에 시간을 쓰는 일이다.

JSON으로 바꾸지 않는 이유는 전체 스펙이 YAML로 정해져 있고, 사람이 손으로 쓰는 config에 JSON은 주석을 달 수 없으며 따옴표와 쉼표가 거슬리기 때문이다.

## 11. 후속 사이클에 남기는 것

- 브라우저 탭 제어 (4단계). Apple Events 권한이 대상 앱별로 필요하다.
- 워크스페이스 이름 레지스트리와 `ws open <name>`, `ws list` (5단계). config 파일 위치 규약도 그때 정한다.
- Space 지정. yabai 선택 의존으로 방향을 정해뒀다. 다른 Space의 창에 접근할 수 없는 제약도 그때 함께 풀린다.
