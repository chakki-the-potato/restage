# 3단계 검증 결과 — 워크스페이스 실행 루프

측정일: 2026-08-23
머신: 내장 `visibleFrame=(0,57,1728,1027)`, 외장 `visibleFrame=(-419,1117,2560,1410)`, `primaryMaxY=1117`
검증 앱: safari, notion, iterm
Rectangle 종료 상태, `caffeinate`로 화면 잠금 차단

## 결과

### 2화면 배치

`examples/two-screens.yaml` — 내장에 좌우 분할 2개, 외장에 전체 1개.

```
SCREEN      APP         RESULT            EXPECTED               ACTUAL
main        safari      placed            0,33 864x1027          0,33 864x1027
main        notion      placed            864,33 864x1027        864,33 864x1026
side        iterm       placed            -419,-1410 2560x1410   -419,-1410 2560x1410
```

외장 디스플레이 목표의 y가 음수인 것은 그 화면이 주 디스플레이 위쪽에 있어 AX 좌표계에서 음수 영역을 차지하기 때문이다. 실측이 목표와 정확히 일치한다.

### 멱등성

같은 명령을 두 번, 세 번 반복 실행했다.

```
main        safari      alreadySatisfied
main        notion      alreadySatisfied
side        iterm       alreadySatisfied
```

창이 전혀 움직이지 않는다. Notion이 1회차에 요청보다 1pt 작게 안착했는데(`864x1026`) tolerance 2pt가 흡수했다.

### 부분 실패

없는 앱과 연결되지 않은 디스플레이를 섞었다.

```
main        safari          alreadySatisfied
main        nonexistent-app failed            레지스트리에 없는 앱입니다: nonexistent-app
missing     -               skipped           외장 디스플레이 9번이 연결되어 있지 않습니다
종료 코드 1
```

한 항목의 실패가 나머지를 막지 않는다.

### 브라우저 항목

```
web         safari      placed
web         chrome      skipped   브라우저 탭 제어는 아직 구현되지 않았습니다
종료 코드 1
```

조용히 무시되지 않고 결과에 드러난다.

### config 오류

```
restage open /tmp/restage-bad.yaml
config 형식이 올바르지 않습니다. DecodingError.dataCorrupted: Data was corrupted.
Path: screens[0].items[0].slot. Debug description: Cannot initialize Slot from invalid String value nonsense
종료 코드 2
```

오류 메시지에 경로가 남아 어느 항목의 어느 필드인지 바로 보인다. 종료 코드가 2인 것은 파일을 고쳐야 하는 상황이라 환경 문제(1)와 구분하기 위해서다.

## 검증 중 발견해 수정한 것

### 1. `NSScreen.visibleFrame`이 보조 디스플레이의 메뉴바를 보고하지 않는다

외장 디스플레이에 `slot: full`로 배치하면 높이가 30px 모자란 채 실패했다. `visibleFrame`은 외장의 `topInset`을 0으로 보고하는데 OS는 실제로 30px를 예약한다.

처음에는 "디스플레이별 개별 Space라 외장에도 메뉴바가 있고, `visibleFrame`이 그걸 반영하지 않는 OS 동작"으로 결론 내릴 뻔했다. 메뉴바 두께를 추정해 빼는 방향이었다.

실제 원인은 달랐다. **프로세스를 GUI 앱으로 초기화하지 않으면 AppKit이 보조 디스플레이의 정확한 가용 영역을 계산하지 않는다.** 같은 프로세스 안에서 측정해 확인했다.

```
NSApplication 초기화 전: [1] visible=(-419,1117,2560,1440) topInset=0
초기화 후 (.accessory):  [1] visible=(-419,1117,2560,1410) topInset=30
주 디스플레이는 양쪽 다 topInset=33으로 동일
```

`NSWindow.constrainFrameRect(_:to:)`도 초기화 후에는 `topInset=30`을 돌려준다. `NSStatusBar.system.thickness`는 22를 반환해 이 값과 무관하다. 즉 추정으로는 얻을 수 없는 값이었다.

`AppKitBootstrap.ensureGUIApplication()`이 `NSApplication.shared`를 만들고 정책이 `.prohibited`일 때만 `.accessory`로 바꾼다. 이미 정해진 정책은 덮지 않는다. 후속 사이클의 메뉴바 UI가 `.regular`를 쓰게 되면 그 설정이 유지되어야 하기 때문이다.

수정 후 외장 배치가 첫 시도에 정확히 맞는다.

### 2. `isFullScreen`이 창이 놓인 디스플레이를 확인하지 않았다

크기만 보고 판정해서, 외장 디스플레이를 채운 일반 창(2560x1410)을 주 디스플레이(1728x1027) 기준 전체화면으로 오판했다.

멱등 판정의 핵심 함수라 그대로 뒀으면 이미 전체화면이라고 착각해 배치를 건너뛰었을 것이다. 창 중심이 해당 디스플레이의 AX 영역 안에 있는지까지 확인하도록 고쳤다.

### 3. 보고서가 선언 순서를 어겼다

실행 실패를 먼저 모아 내보내는 구조라 실패한 항목이 성공한 항목보다 앞에 나왔다. config 배열 순서가 곧 순서라는 이 프로젝트의 규약을 보고서가 어기고 있었다.

실행은 여전히 먼저 전부 시도하되(여러 앱의 기동 시간이 겹치도록), 보고는 선언 순서대로 내도록 분리했다.

### 4. 긴 앱 이름이 표를 깨뜨렸다

열 너비를 넘는 값 뒤에 다음 열이 그대로 붙었다. 최소 한 칸은 띄우도록 고쳤다.

## probe 보호 앱

검증 하네스가 절대 건드리면 안 되는 앱을 `AppRegistry.protected`로 코드에 두었다.

- `cursor` — 이 저장소의 개발이 Cursor 안에서 이뤄진다. 종료하면 세션이 끊긴다.
- `chrome` — 사용자가 작업 중이다.

`probe --app chrome`은 실행 전에 거부된다. 이전에는 서브에이전트 지시문에 "건드리지 마세요"라고 적는 것으로 막고 있었고, 실제로 한 번 실패해 Cursor가 종료되며 세션이 끊긴 적이 있다. 지시문이 아니라 코드로 막는다.

`restage open`은 영향받지 않는다. config에 선언되면 정상 배치한다. 보호 대상은 콜드 스타트의 앱 종료뿐이다.

## 전체화면을 통합 검증에서 제외한 이유

2단계에서 확인했듯 전체화면은 편도다. AX로 넣을 수는 있어도 뺄 수 없고, 검증할 때마다 전용 Space가 남는다. 실제로 앞 사이클에서 이것으로 사용자 머신에 데스크탑 6개를 남긴 적이 있다.

전체화면 진입 자체는 2단계에서 7종에 대해 검증했다. 3단계에서 새로 확인할 것은 `CurrentState.isFullScreen`을 통한 멱등 판정인데, 이는 위 2번 수정으로 다뤘고 파괴적 검증을 반복할 만한 가치가 없다고 판단했다.

`mode: fullscreen` config를 쓰면 동작한다. 다만 실행 후 `ctrl+cmd+F`로 직접 해제해야 한다.

## 남은 항목

- IINA와 Xcode는 이번 검증 앱에 넣지 않았다. 2단계에서 확인한 크기 제약(Xcode 최소 너비 940, IINA 크기 고정 창)이 그대로 적용된다.
- Discord 웜 스타트의 전체화면 전환이 3~4회 중 1회 실패한다. 2단계에서 관측했고 원인 미확정이다.
