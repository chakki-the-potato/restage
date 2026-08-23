# restage

macOS에서 미리 선언한 앱·창 배치를 한 번에 복원하는 도구.

작업을 시작할 때마다 앱을 띄우고 창을 끌어다 놓는 일을 YAML 한 장으로 대신한다.

```yaml
hotkey: "ctrl+alt+cmd+1"
workspace: dev
screens:
  - id: main
    display: builtin
    items:
      - {type: app, app: cursor, slot: left-half}
      - {type: app, app: iterm,  slot: right-half}
```

```
restage open dev
```

## 무엇을 하는가

- 선언한 앱을 실행하고 지정한 자리에 창을 놓는다
- 브라우저 탭을 연다
- 여러 디스플레이에 나눠 배치한다
- 메뉴바에서 클릭하거나 전역 단축키로 실행한다

**좌표를 저장하지 않는다.** `left-half` 같은 이름으로 저장하고 실행 시점의 화면 크기로 계산한다. 모니터가 바뀌어도 config를 고칠 필요가 없다.

**이미 원하는 상태면 건드리지 않는다.** 같은 명령을 두 번 실행해도 창이 다시 움직이지 않는다.

**선언하지 않은 것은 손대지 않는다.** config에 없는 앱은 숨기지도 종료하지도 않는다. 브라우저 탭도 이미 열린 것을 닫지 않고 없는 것만 추가한다.

## 요구 사항

- macOS 13 이상
- Xcode 명령줄 도구 (Swift 6.0 이상)
- 접근성 권한

## 설치

```bash
git clone https://github.com/chakki-the-potato/restage.git
cd restage
swift build -c release
```

빌드된 바이너리는 `.build/release/restage`에 있다. PATH에 두려면 심볼릭 링크를 건다.

```bash
ln -s "$PWD/.build/release/restage" /usr/local/bin/restage
```

### 접근성 권한

창을 옮기려면 접근성 권한이 필요하다. 승인 대상은 **명령을 실행한 터미널 앱**이다. iTerm에서 실행한다면 iTerm을 승인한다.

시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 터미널 앱을 추가하고 켠다. 켠 뒤 터미널을 완전히 종료했다 다시 연다.

권한이 없으면 `restage`가 안내 메시지를 출력하고 멈춘다.

## 워크스페이스 작성

config는 `~/.config/restage/<이름>.yaml`에 둔다.

```bash
mkdir -p ~/.config/restage
cp examples/dev.yaml ~/.config/restage/
```

`examples/`에 단일 화면, 브라우저 탭, 듀얼 모니터 예시가 있다.

### 전체 형식

```yaml
workspace: dev            # 필수. 워크스페이스 이름
hotkey: "ctrl+alt+cmd+1"  # 선택. 메뉴바 실행 중에만 동작

screens:
  - id: main              # 필수. 보고서에 표시된다
    display: builtin      # builtin | external-N | any. 기본값 any
    mode: desktop         # desktop | fullscreen. 기본값 desktop
    anchor: cursor        # 선택. 이 화면 처리 후 포커스할 앱
    items:
      - {type: app, app: cursor, slot: left-half}
      - {type: app, app: iterm,  slot: right-half}

  - id: web
    display: external-1
    items:
      - type: browser
        app: safari
        window: separate  # separate | shared. 기본값 separate
        slot: full        # 선택. 없으면 창 크기를 건드리지 않는다
        tabs:
          - https://example.com
          - https://example.org
```

### slot

`full`, `left-half`, `right-half`, `top-half`, `bottom-half`, `q1`~`q4`, `centered`

사분면은 읽는 순서다. `q1` 좌상, `q2` 우상, `q3` 좌하, `q4` 우하.

`type: app`에서 생략하면 `full`이다. `type: browser`에서 생략하면 창 크기를 건드리지 않는다.

### display

- `builtin` — 주 디스플레이
- `external-N` — 외장 디스플레이. 프레임 원점 기준으로 정렬한 뒤 N번째(1부터)
- `any` — 주 디스플레이. 현재 `builtin`과 동작이 같다

연결되지 않은 디스플레이를 지정하면 그 화면만 건너뛰고 사유를 보고한다.

### 창이 여러 개인 앱

`title`로 어느 창을 옮길지 지정한다. 창 제목의 일부를 적으면 된다.

```yaml
items:
  - {type: app, app: safari, slot: left-half,  title: 시작 페이지}
  - {type: app, app: safari, slot: right-half, title: 작업}
```

없으면 가장 최근 활성 창을 고른다.

### 지원하는 앱 이름

`app:`에 적는 이름은 논리 이름이며 `Sources/RestageKitDarwin/AppRegistry.swift`에 매핑되어 있다.

```
safari  iterm  xcode  iina  chrome  cursor  discord  notion  claude  kakaotalk
```

여기 없는 앱을 쓰려면 그 파일에 bundle ID를 추가한다. bundle ID는 다음으로 확인한다.

```bash
mdls -name kMDItemCFBundleIdentifier -r /Applications/앱이름.app
```

## 사용법

```bash
restage open dev              # 이름으로
restage open ./my.yaml        # 경로로
restage list                  # 등록된 워크스페이스
restage menubar               # 메뉴바 실행
```

`restage open`은 결과를 표로 출력한다.

```
SCREEN   APP      RESULT            EXPECTED         ACTUAL           NOTE
main     safari   placed            0,33 864x1027    0,33 864x1027
main     notion   alreadySatisfied  864,33 864x1027  -                이미 목표 상태
```

| 결과 | 의미 |
|---|---|
| `placed` | 배치했다 |
| `alreadySatisfied` | 이미 목표 상태여서 건드리지 않았다 |
| `constrained` | 앱이 막았다. 최소 크기, 크기 고정, 전체화면 미지원 |
| `unreachable` | 창이 다른 Space에 있어 접근할 수 없다 |
| `failed` | 그 외 실패 |
| `skipped` | 건너뛴 화면이나 미지원 기능 |

한 항목이 실패해도 나머지는 계속 진행하고, 마지막에 실패 목록을 사유와 함께 보고한다.

## 메뉴바와 단축키

```bash
restage menubar
```

메뉴바 아이콘에서 워크스페이스를 클릭해 실행한다. config의 `hotkey`는 이때 등록된다.

앱 번들로 만들면 Finder에서 실행하거나 로그인 시 자동 실행할 수 있다.

```bash
./scripts/make-app.sh
open build/restage.app
```

**앱 번들은 별도로 접근성 승인을 받아야 한다.** 그리고 adhoc 서명이라 **재빌드할 때마다 승인이 무효화된다.** 개발 중에는 CLI를 쓰고, 코드가 안정된 뒤에 번들을 만드는 편이 낫다.

메뉴바 아이콘이 보이지 않으면 Hidden Bar 같은 메뉴바 관리 도구의 숨김 영역을 확인한다. 그런 도구는 항목을 화면 밖으로 밀어내는 방식으로 숨긴다.

## 알려진 한계

macOS가 허용하지 않아 생기는 제약이 대부분이다.

**특정 데스크탑(Space)에 배치할 수 없다.** 공개 API가 없다. 대신 `mode: fullscreen`을 쓰면 macOS가 전용 Space를 만들어 준다.

**전체화면은 편도다.** 넣을 수는 있어도 뺄 수 없다. 전체화면 앱의 창은 전용 Space로 옮겨지는데 그 Space로 전환할 방법이 없기 때문이다. `ctrl+cmd+F`로 직접 해제해야 한다.

**다른 Space의 창은 다룰 수 없다.** 조회조차 되지 않으며 `unreachable`로 보고된다.

**일부 앱은 최소 크기를 강제한다.** Xcode는 너비 940, KakaoTalk은 높이 640 아래로 줄지 않는다. `constrained`로 보고된다.

**브라우저 탭 순서는 첫 실행에만 정확하다.** 이후 추가되는 탭은 창 끝에 붙는다. 순서를 보장하려면 기존 탭을 닫아야 하는데 사용자 작업을 지우게 되므로 그렇게 하지 않는다.

**브라우저는 Chrome과 Safari만 지원한다.** 브라우저 탭 제어에는 Apple Events 권한이 대상 앱별로 최초 1회 필요하다.

**화면이 잠겨 있으면 동작하지 않는다.** 잠긴 상태에서는 접근성 API가 창을 조회하지 못한다. `restage`가 이를 감지해 사유를 밝히고 멈춘다.

## 개발

```bash
swift build
swift test        # 97개
```

검증용 하네스가 있다.

```bash
restage probe --slot left-half --warm-only
```

실제 앱을 띄워 배치 성공률을 측정한다. `--warm-only` 없이 실행하면 콜드 스타트를 재현하려고 **앱을 종료했다 다시 띄운다.** 작업 중인 앱이 있다면 주의한다.

`AppRegistry.protected`에 있는 앱은 probe 대상에서 제외된다.

### 저장소 구성

```
Sources/RestageKit/         OS에 의존하지 않는 스키마·검증·좌표 계산
Sources/RestageKitDarwin/   AX·AppKit·AppleScript 구현
Sources/restage/            CLI와 메뉴바
docs/superpowers/           설계 스펙과 검증 기록
```

`docs/`는 개발 과정에서 남긴 설계 결정과 실측 기록이다. 사용 설명서가 아니라, 왜 그렇게 만들었는지와 macOS가 실제로 어떻게 동작하는지를 적어둔 것이다. 같은 문제를 겪는 사람에게는 참고가 될 수 있다.

## 라이선스

MIT. `LICENSE` 참조.
