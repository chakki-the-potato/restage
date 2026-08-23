# 5단계 검증 결과 — 워크스페이스 레지스트리와 CLI

측정일: 2026-08-23
config 디렉토리: `~/.config/restage/`

## 결과

### `restage list`

`dev.yaml`, `research.yaml`, 그리고 일부러 깨뜨린 `broken.yaml`을 두고 실행했다.

```
NAME             SCREENS  ITEMS  STATUS
broken                 -      -  config 형식이 올바르지 않습니다. DecodingError.dataCorrupted:
                                 Data was corrupted. Path: screens[0].items[0].slot.
                                 Debug description: Cannot initialize Slot from invalid String value nonsense
dev                    1      2  ok
research               1      1  ok
종료 코드 1
```

깨진 config가 목록에서 사라지지 않고 정확한 사유와 함께 나온다. 오류가 하나라도 있으면 종료 코드가 1이다.

### 이름으로 열기

```
restage open dev
main  safari  placed            0,33 864x1027    0,33 864x1027
main  notion  alreadySatisfied  864,33 864x1027  -                이미 목표 상태
종료 코드 0
```

### 기존 경로 방식 유지

```
restage open examples/dev.yaml
alreadySatisfied 2  총 2건 — 완료
종료 코드 0
```

같은 내용의 config이므로 두 번째 실행은 전부 `alreadySatisfied`다. 3~4단계에서 만든 멱등성이 경로 해석 방식과 무관하게 유지된다.

### 찾지 못했을 때

```
restage open devv
'devv' 워크스페이스를 찾을 수 없습니다: /Users/ichanhui/.config/restage/devv.yaml
등록된 워크스페이스: broken, dev, research
종료 코드 2
```

이름을 틀렸을 때 후보를 함께 보여준다. 사용자가 다시 `list`를 칠 필요가 없다.

### 디렉토리가 없을 때

구현 직후 `~/.config/restage`가 없는 상태에서 확인했다.

```
restage list
워크스페이스 디렉토리가 없습니다: /Users/ichanhui/.config/restage
mkdir -p /Users/ichanhui/.config/restage 로 만들고 <이름>.yaml 파일을 두세요
종료 코드 2
```

디렉토리를 자동으로 만들지 않는다. 사용자가 의도하지 않은 위치에 디렉토리가 생기는 것보다 안내가 낫다고 보았다.

## 이번 단계에서 수정할 것이 없었던 이유

3~4단계와 달리 검증 중 발견해 고친 것이 없다. 이 단계는 실제 앱, AX, AppleScript, Space 어느 것도 건드리지 않고 파일 시스템과 문자열만 다루기 때문이다.

앞선 단계들에서 나온 문제는 전부 OS 동작이 문서나 직관과 달라서 생긴 것이었다. `NSScreen.visibleFrame`이 프로세스 초기화 상태에 따라 다른 값을 주거나, `tell` 블록 안에서 `tab`이 다른 것을 가리키거나, AX가 현재 Space의 창만 열거하는 식이었다. 그런 표면이 없으면 계획대로 굴러간다.

## 알려진 한계

- 디렉토리 경로를 환경변수로 바꿀 수 없다. `WorkspaceRegistry`가 주입은 받지만 CLI에서 노출하지 않는다. 설정 경로가 둘이 되면 "내 config가 어디 있는가"가 한눈에 보이지 않기 때문이다.
- `restage list`는 각 config를 전부 파싱한다. 워크스페이스가 수백 개가 되면 느려질 수 있으나 그런 사용은 상정하지 않았다.
