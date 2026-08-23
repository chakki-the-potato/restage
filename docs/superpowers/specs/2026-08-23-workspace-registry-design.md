# restage 5단계 설계 — 워크스페이스 레지스트리와 CLI

작성일: 2026-08-23
스코프: 전체 스펙 8절 작업 순서의 5단계
선행: `2026-08-23-browser-tabs-design.md` (4단계)
상태: 승인됨

## 1. 목표

워크스페이스를 파일 경로가 아니라 이름으로 연다.

```
restage open dev
restage list
```

완료 기준은 다음과 같다.

- `~/.config/restage/dev.yaml`이 있으면 `restage open dev`로 열린다.
- `restage list`가 등록된 워크스페이스를 표로 보여준다.
- 잘못된 config도 목록에서 숨기지 않고 오류와 함께 표시한다.
- 기존 `restage open <path>` 사용법이 그대로 동작한다.

## 2. 명령 이름

전체 스펙은 `ws open <name>`, `ws list`로 적혀 있으나 바이너리 이름은 `restage`를 유지한다.

`ws`는 너무 짧아 다른 도구와 충돌할 위험이 있고, 저장소·제품명과 어긋나며, Homebrew cask 배포에서 이름이 갈라진다. 짧은 이름을 원하는 사용자는 shell alias를 만들면 된다.

## 3. config 위치

```
~/.config/restage/<name>.yaml
```

이 머신에는 이미 `~/.config`가 있고 gh, git, fish 등이 쓰고 있다. XDG 관례를 따르며, 손으로 열어 고치기 쉽고 dotfiles 저장소에 넣기도 좋다.

`~/Library/Application Support/`를 쓰지 않은 이유는 경로가 길어 손으로 편집하기 번거롭고 dotfiles로 관리하기 어렵기 때문이다. 후속 사이클의 메뉴바 앱도 같은 디렉토리를 읽으면 되므로 문제되지 않는다.

환경변수로 재정의하는 방안은 채택하지 않았다. 설정 경로가 둘이 되면 "내 config가 어디 있는가"가 한눈에 보이지 않는다. 다만 `WorkspaceRegistry`는 디렉토리를 주입받도록 만들어 테스트에서 임시 디렉토리를 쓸 수 있게 한다.

## 4. 이름과 경로 구분

`restage open`의 인자는 이름일 수도 경로일 수도 있다. 다음 규칙으로 가른다.

**경로로 본다** — 다음 중 하나라도 해당하면.

- `/`를 포함한다 (`./dev.yaml`, `~/x/dev.yaml`, `/tmp/a.yaml`)
- `.yaml` 또는 `.yml`로 끝난다

**그 외에는 이름으로 본다.** `~/.config/restage/<name>.yaml`을 찾는다.

이 규칙을 고른 이유는 기존 사용법을 깨지 않으면서 새 사용법을 더하기 위해서다. 3~4단계에서 쓰던 `restage open examples/dev.yaml`이 그대로 동작한다.

경로 앞의 `~`는 홈 디렉토리로 확장한다.

## 5. `restage list`

`~/.config/restage/` 안의 `*.yaml`과 `*.yml`을 이름순으로 나열한다.

```
NAME       SCREENS  ITEMS  STATUS
dev              1      2  ok
split            2      3  ok
broken           -      -  config 형식이 올바르지 않습니다. Path: screens[0].items[0].slot ...
```

`SCREENS`는 화면 개수, `ITEMS`는 모든 화면의 항목 수 합계다. 앱 항목과 브라우저 항목을 함께 센다.

**파싱에 실패한 config를 목록에서 빼지 않는다.** 목록에 없으면 사용자는 파일이 없는 줄 알고 엉뚱한 곳을 찾는다. 오류와 함께 보여줘야 고칠 수 있다.

이는 1~4단계에서 반복해 확인한 원칙의 연장이다. 화면이 잠겨 모든 항목이 실패했을 때 사유를 감췄던 것, 다른 Space의 창을 "창 없음"으로 보고했던 것 모두 같은 실패 방식이었다.

## 6. 찾지 못했을 때

**디렉토리가 없을 때**

```
워크스페이스 디렉토리가 없습니다: /Users/x/.config/restage
mkdir -p ~/.config/restage 로 만들고 <이름>.yaml 파일을 두세요
```

**이름을 찾지 못했을 때**

```
'devv' 워크스페이스를 찾을 수 없습니다: /Users/x/.config/restage/devv.yaml
등록된 워크스페이스: dev, split, research
```

이름을 틀렸을 때 "없습니다"만 내면 사용자가 다시 `list`를 쳐야 한다. 후보를 함께 보여준다.

## 7. 모듈 경계

```
Sources/
  RestageKit/
    WorkspaceRegistry.swift   디렉토리 열거와 이름 해석

  restage/
    ListCommand.swift         restage list
    OpenCommand.swift         (수정) 이름 해석 추가
    main.swift                (수정) list 서브커맨드 추가
```

`WorkspaceRegistry`는 디렉토리 경로를 주입받는다. 기본값은 `~/.config/restage`다. 주입 가능하게 만드는 이유는 단위 테스트에서 임시 디렉토리를 쓰기 위해서이며, 그래야 테스트가 사용자 홈 디렉토리를 건드리지 않는다.

`ConfigLoader`는 수정하지 않는다. 레지스트리는 경로를 결정할 뿐이고 파일을 읽고 검증하는 책임은 그대로 `ConfigLoader`에 있다.

## 8. 인터페이스

```swift
public struct WorkspaceRegistry {
    public static let defaultDirectory: String   // ~/.config/restage

    public init(directory: String = WorkspaceRegistry.defaultDirectory)

    /// 인자를 이름 또는 경로로 해석해 실제 파일 경로를 돌려준다.
    public func resolve(_ argument: String) throws -> String

    /// 디렉토리의 워크스페이스 목록. 파싱 실패도 포함한다.
    public func list() throws -> [WorkspaceEntry]
}

public struct WorkspaceEntry: Sendable {
    public let name: String
    public let path: String
    public let screenCount: Int?   // 파싱 실패 시 nil
    public let itemCount: Int?
    public let error: String?
}
```

`resolve`가 던지는 오류는 `ConfigError`에 두 케이스를 추가해 쓴다.

- `directoryNotFound(path:)`
- `workspaceNotFound(name:path:available:[String])`

## 9. 테스트

### 9.1 단위 테스트

`WorkspaceRegistry`를 임시 디렉토리로 테스트한다. 실제 앱도 홈 디렉토리도 건드리지 않는다.

이름과 경로 구분

- `dev` → `<dir>/dev.yaml`
- `dev.yaml` → 경로로 취급
- `./dev.yaml`, `/tmp/dev.yaml`, `~/x/dev.yaml` → 경로로 취급
- `~`가 홈 디렉토리로 확장되는지

목록

- 유효한 config 여러 개가 이름순으로 나열되는지
- 화면 수와 항목 수가 맞는지
- 파싱 실패한 config가 목록에 남고 오류 문구가 채워지는지
- `.yaml`과 `.yml` 둘 다 인식하는지
- yaml이 아닌 파일은 무시하는지
- 빈 디렉토리에서 빈 목록

오류

- 디렉토리가 없을 때 `directoryNotFound`
- 이름을 못 찾을 때 `workspaceNotFound`이고 `available`에 실제 목록이 담기는지

### 9.2 통합 검증

`~/.config/restage/`에 파일 하나를 두고 확인한다.

- `restage list`가 그것을 보여주는지
- `restage open <name>`이 동작하는지
- 기존 `restage open <path>`가 여전히 동작하는지
- 없는 이름을 넣었을 때 후보 목록이 나오는지

실제 앱을 움직이는 부분은 3~4단계에서 이미 검증했으므로, 여기서는 경로 해석까지만 확인하고 배치 결과는 기존 config를 재사용한다.

## 10. 후속 사이클에 남기는 것

- 메뉴바 UI (6단계). 같은 `~/.config/restage/`를 읽는다.
- 단축키 바인딩 (7단계). config의 `hotkey` 필드를 그때 사용한다.
- Space 지정. yabai 선택 의존.
