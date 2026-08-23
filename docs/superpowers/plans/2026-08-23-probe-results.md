# 1단계 검증 결과 — 창 배치

측정일: 2026-08-23
대상: 표본 9종 (cursor는 표본에서 제외)
머신: 내장 디스플레이 `frame=(0,0,1728,1117)`, `visibleFrame=(0,57,1728,1027)`, `primaryMaxY=1117`
외장 디스플레이 1대 연결됨 `frame=(-419,1117,2560,1440)`. 이번 스코프는 주 디스플레이만 다룬다.
Rectangle은 측정 중 종료 상태.

## 결과

`right-half`와 `left-half` 두 슬롯으로 각각 전체를 돌렸고 결과가 동일했다. 슬롯을 바꿔 실행하면 앱이 기억하는 크기와 목표가 달라지므로 실제 리사이즈가 강제된다.

| 앱 | 콜드 | 웜 | 시도 | 비고 |
|---|---|---|---|---|
| safari | PASS | PASS | 1 | |
| iterm | PASS | PASS | 1 | |
| xcode | CONSTRAINED | CONSTRAINED | - | 크기 고정 창 740x460 |
| iina | CONSTRAINED | CONSTRAINED | - | 크기 고정 창 640x400 |
| chrome | PASS | PASS | 1 | |
| discord | PASS | PASS | 4 | Electron 자가 리사이즈 |
| notion | PASS | PASS | 1 | |
| claude | PASS | PASS | 1 | |
| kakaotalk | PASS | PASS | 1 | |

집계: PASS 14 / CONSTRAINED 4 / FAIL 0 (18케이스). 두 슬롯 모두 동일.

소요 시간은 대부분 30~60ms, 콜드 스타트의 iterm과 chrome이 110~190ms, discord가 150ms 안팎이다.

## CONSTRAINED 사유

두 건 모두 앱이 가진 유일한 창이 크기 변경을 허용하지 않는다. `AXUIElementIsAttributeSettable`이 `AXSize`에 대해 false를 반환한다. 위치는 정상 적용된다.

- **Xcode**: "Welcome to Xcode" 창. `role=AXWindow`, `subrole=AXUnknown`, 740x460 고정. 프로젝트를 열면 리사이즈 가능한 창이 생기지만, 프로젝트 없이 기동하면 이 창뿐이다.
- **IINA**: 시작 창. `role=AXWindow`, `subrole=AXStandardWindow`, 640x400 고정. 영상을 열면 리사이즈 가능한 창이 생긴다.

둘 다 고칠 수 없는 앱 동작이므로 실패가 아니라 제약으로 분류한다.

## 검증 중 발견해 수정한 것

계획 문서만으로는 드러나지 않았고 실제 앱을 돌려서야 나온 문제들이다.

### 1. 일부 앱은 최전면이 되어야 AX 창 트리를 만든다

Safari는 창이 화면에 보이고 AppleScript가 `count windows`로 1을 반환하는 상태에서도 `AXWindows`가 빈 배열을 돌려준다. System Events로 교차 확인해도 동일하므로 우리 코드 문제가 아니라 Safari의 AX 동작이다.

`AppLauncher`가 `configuration.activates = false`로 앱을 띄우기 때문에 이 상태에 걸린다. 활성화하면 500ms 안에 창이 노출된다.

활성화 방법도 문제였다. 다음을 비교 측정했다.

| 방법 | 결과 |
|---|---|
| 아무것도 안 함 | 3초 후에도 AX 창 0개 |
| `NSRunningApplication.activate()` | 3초 후에도 0개 |
| AX `AXFrontmost = true` | 500ms 후 1개 |

`NSRunningApplication.activate()`는 호출하는 쪽이 GUI 앱이 아니면 macOS가 무시한다. 이 도구는 CLI라 그 경로가 아무 효과도 내지 못한다. AX는 접근성 권한이 이미 있으므로 동작하고, Apple Events 권한을 새로 요구하지도 않는다.

`WindowWaiter`가 750ms 안에 창을 못 찾으면 한 번만 `AXFrontmost`를 설정하고 계속 폴링한다.

### 2. Electron 앱의 스플래시 창을 본창으로 오인

Discord는 기동 직후 300x300 고정 크기 창을 띄우고 잠시 뒤 1280x870 본창으로 교체한다. 초기 `waitForWindow`는 `role`과 크기만 봤기 때문에 스플래시를 잡았고, 위치는 적용되는데 크기만 실패했다.

`AXSize`가 설정 가능한지를 조건에 추가해 스플래시를 건너뛴다. 다만 Xcode와 IINA처럼 가진 창이 전부 크기 고정인 앱이 있으므로, 4초(`splashGrace`) 동안 리사이즈 가능한 창이 안 나오면 고정 크기 창을 폴백으로 반환한다. 그래야 "창이 없다"는 잘못된 보고 대신 크기 제약이라는 정확한 사유가 나간다.

이 판별을 넣기 전에는 두 앱 모두 CONSTRAINED로 분류됐는데, Discord의 경우 실제 버그를 제약으로 덮는 것이었다. 본창이 따로 있는지 직접 확인해서 잡았다.

### 3. 배치 도중 창 요소가 무효화됨

Discord는 기동 중 창을 파괴하고 새로 만드는 경우가 있어, 잡아둔 `AXUIElement`가 도중에 무효가 된다. 그러면 `AXPosition` 조회가 실패해 "창 좌표를 조회할 수 없습니다"로 끝난다.

`AXWindow`가 소유 프로세스의 pid를 들고 있게 하고, 배치 실패 시 요소가 무효면 창을 다시 찾아 한 번 재시도한다.

### 4. 수렴 루프의 상한이 횟수였다

초기값은 3회 시도 / 3초였다. Discord 콜드 스타트는 4~7회를 쓰는데, 한 번 시도가 30~40ms라 횟수가 먼저 소진되고 시간은 한참 남았다. 상한을 40회 / 8초로 바꿔 시간이 주 제약이 되게 했다. 루프는 수렴하면 즉시 빠져나오므로 빠른 앱에는 비용이 없다.

여기에 더해 배치를 시작하기 전에 창 크기가 안정될 때까지 최대 2초 기다린다. 앱이 자체 레이아웃을 끝내기 전에 배치하면 서로 덮어쓰기를 반복한다.

### 5. `waitForWindow` 타임아웃

권장값 5초로는 Xcode가 걸린다. 실측상 Xcode는 콜드 스타트에서 창이 나오기까지 3.5초가 걸리고, 기동 중에는 AX 호출 자체가 지연되어 예산을 더 먹는다. 15초로 올렸다. 창을 찾으면 즉시 반환하므로 정상 케이스에 비용이 없다.

## 검증 방법의 한계

콜드 스타트 검증은 앱이 직전 배치 위치를 기억하면 약해진다. 목표와 같은 크기로 뜨면 리사이즈가 일어나지 않아 사실상 아무것도 검증하지 않는다. 실제로 Claude에서 이 현상을 관찰했다.

그래서 최종 측정은 `right-half`와 `left-half`를 번갈아 돌렸다. 앱이 기억한 슬롯과 목표 슬롯이 항상 다르므로 매번 실제 리사이즈가 강제된다.

## 표본에서 cursor를 제외한 이유

probe의 콜드 스타트는 대상 앱을 종료한다. 이 저장소의 개발이 Cursor 안에서 이뤄지므로 cursor를 표본에 두면 검증이 자기 자신을 죽인다. 실제로 작업 중 한 번 그렇게 세션이 끊겼다.

`AppRegistry.probeSample`에서 빼되 매핑에는 남겨서 `--app cursor`로 개별 조회는 계속 가능하다. Electron 자가 리사이즈는 discord, notion, claude 3종이 덮으므로 커버리지 손실은 없다.

참고로 Task 8·9 진행 중 단일 창 배치로는 Cursor에서 성공을 확인했다. 외장 모니터에 있던 창을 내장 화면 좌측 절반으로 첫 시도, 105ms에 옮겼다. 콜드/웜 2케이스 정식 검증은 아니다.
