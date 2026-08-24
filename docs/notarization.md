# 서명과 공증

받는 사람이 경고 없이 앱을 열게 하려면 Developer ID로 서명하고 Apple에 공증받아야 한다.
유료 Apple Developer Program이 필요하다.

파이프라인은 이미 붙어 있다. 계정이 생기면 아래 두 가지만 하면 된다.

## 1. Developer ID 인증서 만들기

Xcode → Settings → Accounts → 계정 선택 → Manage Certificates → `+` → **Developer ID Application**

만들어졌는지 확인한다.

```bash
security find-identity -v -p codesigning | grep "Developer ID"
```

## 2. 공증 자격증명 저장하기

앱 암호를 [appleid.apple.com](https://appleid.apple.com)에서 만든다. 계정 비밀번호가 아니다.

```bash
xcrun notarytool store-credentials restage \
  --apple-id <애플 계정> \
  --team-id <팀 ID> \
  --password <앱 암호>
```

팀 ID는 [developer.apple.com/account](https://developer.apple.com/account) 상단에 있다.

## 그다음은 같은 명령이다

```bash
./scripts/make-release.sh 0.3.0
```

`make-release.sh`가 알아서 갈라진다.

| 상태 | 결과 |
|---|---|
| Developer ID 있음 + 자격증명 있음 | 서명·공증된 dmg. **바로 열림** |
| Developer ID 있음 | 서명만. 우클릭 열기 필요 |
| 둘 다 없음 | adhoc. 우클릭 열기 필요 |

공증은 Apple 서버가 처리하므로 몇 분 걸린다.

## 왜 티켓을 앱에 박는가

`stapler staple`이 공증 결과를 앱 안에 넣는다. 두 가지 이점이 있다.

- 받는 사람이 인터넷 없이도 검증된다
- **인증서가 만료된 뒤에도 이미 받아 간 앱은 계속 열린다**

두 번째가 중요하다. 서명에 타임스탬프가 박히므로 나중에 계정을 갱신하지 않아도 배포된
버전은 살아 있다. 갱신하지 않으면 **새 버전을 못 낼 뿐**이다.

## 계정이 생기면 바뀌는 것

README의 설치 안내를 dmg 우선으로 바꾼다.

```
1. Releases에서 dmg 받기
2. 열어서 Applications로 드래그
3. 실행 후 접근성 권한 켜기
```

터미널도, Xcode 명령줄 도구도 필요 없다. 지금 방식은 Swift 컴파일러를 요구하므로
개발자가 아니면 사실상 쓸 수 없다. 그것이 계정으로 사는 가장 큰 것이다.

`Casks/restage.rb`를 tap 저장소에 올리면 `brew install --cask` 경로도 열린다.
