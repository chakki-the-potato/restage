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

## 설치

**Homebrew**

```bash
brew install chakki-the-potato/tap/restage
open $(brew --prefix restage)/restage.app
```

**Homebrew가 없다면**

```bash
curl -fsSL https://raw.githubusercontent.com/chakki-the-potato/restage/main/install.sh | bash
```

둘 다 소스를 받아 이 컴퓨터에서 빌드한다. 직접 빌드한 앱은 Gatekeeper가 막지 않으므로 "확인되지 않은 개발자" 경고도, 우클릭으로 여는 번거로움도 없다.

macOS 13 이상과 Xcode 명령줄 도구가 필요하다. 없으면 설치 스크립트가 안내한다.

### 접근성 권한

창을 옮기려면 접근성 권한이 필요하다. 앱을 처음 열면 안내가 뜬다.

시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 **restage**를 켠다.

터미널에서 쓸 때는 승인 대상이 **명령을 실행한 터미널 앱**이다. iTerm에서 실행한다면 iTerm을 켠다. 켠 뒤 터미널을 완전히 종료했다 다시 연다.

권한이 없으면 안내 메시지를 보여주고 멈춘다.

업그레이드하면 다시 켜야 할 수 있다. 무료 서명은 빌드할 때마다 앱의 신원이 바뀌기 때문이다. 이것을 없애려면 유료 Apple Developer Program의 Developer ID 인증서가 필요하다.

### 소스에서 직접

```bash
git clone https://github.com/chakki-the-potato/restage.git
cd restage
./scripts/make-app.sh          # 메뉴바 앱을 build/restage.app에 만든다
swift build -c release         # CLI만 필요하면
```

## 워크스페이스 만들기

창을 원하는 대로 배치해두고 명령 하나면 된다.

```bash
restage new dev
```

지금 열린 창을 읽어 이렇게 보여준다.

```
현재 창 배치를 읽었습니다.

  main
    1. Safari · 문서       왼쪽 절반   탭 2개
    2. Safari · 메일       오른쪽 절반
  external-1
    3. iTerm               좌하?       [다른 데스크탑]

  ? 는 자리가 애매하다는 뜻입니다. 번호를 눌러 직접 고르세요.
[Enter] 저장   [숫자] 자리 바꾸기   [-숫자] 제외   [+] 앱 추가   [w] 웹 추가   [q] 취소
```

Enter를 누르면 `~/.config/restage/dev.yaml`이 만들어진다.

- 브라우저는 **열려 있는 탭까지 함께 담는다.** 시작 페이지나 새 탭은 담지 않는다
- 자리가 애매하면 `?`가 붙는다. **조용히 추측하지 않는다.** 번호를 눌러 직접 고른다
- 다른 데스크탑에 있는 창도 담는다. 표시가 붙는다
- 같은 앱의 창이 여럿이면 각각 담고 창 제목으로 구분한다
- 안 켜둔 앱은 `+`로, 지금 안 열려 있는 URL은 `w`로 추가한다
- 좌표가 아니라 `left-half` 같은 이름으로 저장된다

메뉴바 아이콘에서 **현재 창 배치로 새로 만들기**를 눌러도 된다. 그쪽은 체크박스로 담을 항목을 고르고, 항목마다 자리를 드롭다운으로 바꾼다. 원하는 앱이 안 켜져 있으면 이름을 적어 넣는다.

목록은 **창을 읽은 시점**의 것이다. 그 뒤에 창을 옮겼다면 **다시 읽기**를 누른다.

### 전체 화면

자리 대신 **전체 화면**을 고르면 그 앱만 전용 데스크탑으로 보낸다. macOS 창 메뉴의 "전체 화면"과 같다.

```yaml
- {type: app, app: Cursor, slot: full, fullscreen: true}
```

캡처할 때 이미 전체화면이던 창은 자동으로 이렇게 담긴다.

### 담기지 않는 창

**제목으로 구분할 수 없는 창은 담지 않는다.** 실행할 때 어느 창인지 정하는 수단이 제목뿐이라, 제목이 비었거나 두 창이 같은 제목을 쓰면 매번 같은 창만 잡힌다. 그런 항목을 담아두면 담긴 줄 알지만 실제로는 동작하지 않는다.

```
Claude 창 3개는 담지 않았습니다. 제목이 같거나 비어 있어 실행할 때 어느 창인지 정할 수 없습니다.
```

**최소화한 창도 담지 않는다.** 위치가 의미 없다.

## config 직접 쓰기

`restage new` 없이 손으로 써도 된다. config는 `~/.config/restage/<이름>.yaml`에 둔다.

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

### 앱 이름

**설치된 앱이면 무엇이든 쓸 수 있다.** Finder에 보이는 이름을 그대로 적는다.

```yaml
- {type: app, app: Figma,           slot: left-half}
- {type: app, app: Microsoft Word,  slot: right-half}
- {type: app, app: KakaoTalk,       slot: q4}
```

대소문자를 가리지 않고, 짧은 이름도 알아듣는다. `chrome`은 `Google Chrome`을, `edge`는 `Microsoft Edge`를 가리킨다. 정확히 일치하는 이름이 있으면 항상 그쪽이 이긴다.

이름이 여럿에 걸리면 후보를 알려주고 멈춘다.

```
'microsoft'에 해당하는 앱이 여럿입니다: Microsoft Edge, Microsoft Word
```

없는 이름이면 비슷한 것을 제안한다.

```
'Noton'이라는 이름의 앱이 설치되어 있지 않습니다. 혹시 이건가요: Notion
```

## 사용법

```bash
restage new dev               # 현재 창 배치로 새로 만들기
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

메뉴바 아이콘을 누르면 패널이 뜬다. 카드를 클릭하면 실행된다.

- 마우스를 올리면 **편집**과 **더보기**가 나타난다
- 더보기에서 **이름 변경**, 단축키 변경, 파일로 열기, 삭제
- 단축키는 원하는 조합을 그냥 누르면 된다. config의 `hotkey` 줄만 바뀌고 나머지는 그대로다
- 삭제는 확인을 받고 휴지통으로 보낸다
- 실행에 실패하면 카드 안에 사유가 붙는다

- `Options`에서 로그인 시 자동 실행, **업데이트 확인**, config 폴더 열기

다른 앱이 이미 쓰는 단축키는 등록되지 않는다. 그때도 카드에 사유가 뜬다.

### 편집

카드의 연필 아이콘을 누르면 만들 때와 같은 창이 뜬다. 항목을 빼거나 자리를 바꾸고 저장한다. YAML을 직접 보고 싶으면 더보기의 **파일로 열기**를 쓴다.

앱 번들로 만들면 Finder에서 실행하거나 로그인 시 자동 실행할 수 있다.

```bash
./scripts/make-app.sh
open build/restage.app
```

**앱 번들은 별도로 접근성 승인을 받아야 한다.** 한 번 켜면 유지된다.

`make-app.sh`가 이 컴퓨터의 코드 서명 인증서를 찾아 쓴다. 인증서로 서명해야 재빌드해도 승인이 유지되기 때문이다. macOS는 승인을 designated requirement에 묶는데 둘의 형태가 다르다.

```
adhoc      designated => cdhash H"f3b2..."
인증서      designated => identifier "com.chakki.restage" and anchor apple generic
                        and certificate leaf[subject.CN] = "Apple Development: ..."
```

adhoc은 코드 해시에 묶이므로 소스가 같아도 다시 컴파일하면 신원이 바뀌고 승인이 풀린다.

Xcode에 Apple 계정을 로그인하면 무료로 Apple Development 인증서가 생긴다. 결제가 필요한 Developer ID는 남에게 배포할 때(공증) 필요하며, 내 컴퓨터에서 쓰는 데는 무료 인증서로 충분하다. 인증서가 하나도 없으면 adhoc으로 서명하고 경고를 낸다.

`RESTAGE_SIGN_IDENTITY` 환경변수로 신원을 지정할 수도 있다.

메뉴바 아이콘이 보이지 않으면 Hidden Bar 같은 메뉴바 관리 도구의 숨김 영역을 확인한다. 그런 도구는 항목을 화면 밖으로 밀어내는 방식으로 숨긴다.

## 알려진 한계

macOS가 허용하지 않아 생기는 제약이 대부분이다.

**특정 데스크탑(Space)에 배치할 수 없다.** 공개 API가 없다. 대신 `mode: fullscreen`을 쓰면 macOS가 전용 Space를 만들어 준다.

**전체화면은 편도다.** 넣을 수는 있어도 뺄 수 없다. 전체화면 앱의 창은 전용 Space로 옮겨지는데 그 Space로 전환할 방법이 없기 때문이다. `ctrl+cmd+F`로 직접 해제해야 한다.

**다른 데스크탑의 창을 다루려면 설정이 하나 필요하다.** 그냥 두면 `unreachable`로 보고된다.

창을 다른 데스크탑으로 옮기는 것은 공개 API로도 비공개 API로도 되지 않는다. 창 서버의
비공개 함수를 직접 불러 확인했고, 다른 앱의 창에는 조용히 무시된다. yabai 같은 도구가
SIP 부분 해제를 요구하는 이유다. 측정 기록은
[space-placement-results](docs/superpowers/plans/2026-08-25-space-placement-results.md)에 있다.

대신 그 데스크탑으로 넘어가는 방법을 쓴다.

시스템 설정 → 데스크탑 및 Dock → **"응용 프로그램으로 전환할 때, 해당 앱의 열린 윈도우가 있는 공간으로 전환"**

켜면 `restage`가 앱을 활성화해 그 데스크탑으로 넘어간 뒤 창을 배치한다. 측정값이다.

```
활성화 전 AX 창 0개  →  AXFrontmost 설정  →  활성화 후 2개
```

전체화면으로 다른 Space에 있던 Safari를 정상 배치하는 것까지 확인했다. 대신 평소에 앱을 전환할 때도 화면이 데스크탑을 넘나든다. 취향이 갈리는 설정이다.

되돌리려면 다음을 실행한다.

```bash
defaults delete com.apple.dock workspaces-auto-swoosh && killall Dock
```

**일부 앱은 최소 크기를 강제한다.** Xcode는 너비 940, KakaoTalk은 높이 640 아래로 줄지 않는다. `constrained`로 보고된다.

**브라우저 탭 순서는 첫 실행에만 정확하다.** 이후 추가되는 탭은 창 끝에 붙는다. 순서를 보장하려면 기존 탭을 닫아야 하는데 사용자 작업을 지우게 되므로 그렇게 하지 않는다.

**Firefox 계열은 탭을 다룰 수 없다.** 탭 제어 어휘를 외부에 열어두지 않기 때문이다. 창 배치는 되지만 `tabs`는 실패로 보고한다.

Safari와 Chromium 계열(Chrome, Edge, Brave, Arc, Whale, Vivaldi)은 같은 경로로 동작한다. **Safari, Chrome, Brave 세 가지로 검증했다.** Edge, Arc, Whale, Vivaldi는 같은 코드를 타지만 확인하지 않았다.

브라우저 탭 제어에는 Apple Events 권한이 대상 앱별로 최초 1회 필요하다.

**화면이 잠겨 있으면 동작하지 않는다.** 잠긴 상태에서는 접근성 API가 창을 조회하지 못한다. `restage`가 이를 감지해 사유를 밝히고 멈춘다.

## 개발

```bash
swift build
swift test        # 185개
```

검증용 하네스가 있다.

```bash
restage probe --slot left-half
```

실행 중인 앱을 대상으로 배치 성공률을 측정한다. 기본값은 아무 앱도 종료하지 않는다.

콜드 스타트까지 보려면 `--cold`를 준다. 대상 앱을 **강제 종료하므로** `--app`으로 하나만 지정해야 하고, 실행 전에 확인을 받는다.

```bash
restage probe --app Safari --cold
```

### 저장소 구성

```
Sources/RestageKit/         OS에 의존하지 않는 스키마·검증·좌표 계산
Sources/RestageKitDarwin/   AX·AppKit·AppleScript 구현, 설치된 앱 검색
Sources/restage/            CLI와 메뉴바
Sources/RestageBrand/       앱 아이콘과 메뉴바 아이콘의 도형 정의
Sources/restage-icon/       .iconset을 굽는 빌드 도구. 번들에는 들어가지 않는다
docs/superpowers/           설계 스펙과 검증 기록
```

`docs/`는 개발 과정에서 남긴 설계 결정과 실측 기록이다. 사용 설명서가 아니라, 왜 그렇게 만들었는지와 macOS가 실제로 어떻게 동작하는지를 적어둔 것이다. 같은 문제를 겪는 사람에게는 참고가 될 수 있다.

## 라이선스

MIT. `LICENSE` 참조.
