#!/bin/bash
# restage 설치 스크립트.
#
#   curl -fsSL https://raw.githubusercontent.com/chakki-the-potato/restage/main/install.sh | bash
#
# 소스를 받아 이 컴퓨터에서 빌드한다. 미리 빌드한 앱을 나눠주려면 Developer ID 인증서로
# 서명하고 공증해야 하는데 유료 계정이 필요하다. 직접 빌드하면 Gatekeeper가 막지 않으므로
# 우클릭으로 여는 번거로움도 없다.
set -euo pipefail

REPO="chakki-the-potato/restage"
APP_DIR="${RESTAGE_APP_DIR:-/Applications}"
BIN_DIR="${RESTAGE_BIN_DIR:-/usr/local/bin}"
MIN_MACOS=13

# 안내는 시스템 언어를 따른다. 설치는 앱을 켜기 전에 도는 것이라 앱 안의 언어 설정을
# 아직 읽을 수 없다.
LANGUAGE="en"
case "$(defaults read -g AppleLanguages 2>/dev/null | sed -n 2p)" in
  *ko*) LANGUAGE="ko" ;;
esac

# 번역을 키 하나에 나란히 둔다. 갈라 두면 한쪽만 고치게 된다.
t() {
  local ko en
  case "$1" in
    need_macos)
      ko="macOS에서만 동작합니다."
      en="This only runs on macOS." ;;
    need_macos_version)
      ko="macOS $MIN_MACOS 이상이 필요합니다. 지금은 $2입니다."
      en="macOS $MIN_MACOS or later is required. This is $2." ;;
    need_clt)
      ko="Xcode 명령줄 도구가 필요합니다. 설치 창을 엽니다."
      en="Xcode command line tools are required. Opening the installer." ;;
    need_clt_after)
      ko="설치가 끝나면 이 명령을 다시 실행하세요."
      en="Run this command again once that finishes." ;;
    no_swift)
      ko="swift를 찾을 수 없습니다. Xcode 명령줄 도구를 확인하세요."
      en="Couldn't find swift. Check the Xcode command line tools." ;;
    fetching)
      ko="restage 소스를 받는 중..."
      en="Fetching the restage source..." ;;
    version)
      ko="  버전 $2"
      en="  version $2" ;;
    latest_source)
      ko="  최신 소스 (공개된 릴리스 없음)"
      en="  latest source (no published release)" ;;
    fetch_failed)
      ko="소스를 받지 못했습니다."
      en="Couldn't fetch the source." ;;
    bad_archive)
      ko="받은 파일이 올바르지 않습니다."
      en="The downloaded archive isn't valid." ;;
    building)
      ko="빌드하는 중... (처음에는 1분 정도 걸립니다)"
      en="Building... (the first build takes about a minute)" ;;
    build_failed)
      ko="빌드에 실패했습니다. 위 메시지를 확인하세요."
      en="The build failed. Check the messages above." ;;
    installing)
      ko="설치하는 중..."
      en="Installing..." ;;
    link_failed)
      ko="  터미널 명령은 연결하지 못했습니다. 앱은 정상 설치됐습니다."
      en="  Couldn't link the terminal command. The app itself installed fine." ;;
    no_bin_dir)
      ko="  $2 가 없어 터미널 명령은 연결하지 않았습니다."
      en="  $2 doesn't exist, so the terminal command wasn't linked." ;;
    installed)
      ko="설치했습니다."
      en="Installed." ;;
    menubar_note)
      ko="메뉴바 오른쪽 위에 아이콘이 생겼습니다."
      en="An icon is now in the menu bar." ;;
    first_time)
      ko="처음 한 번만 해주세요:
  창을 옮기려면 접근성 권한이 필요합니다.
  메뉴바 아이콘을 눌러 안내를 따라가거나,
  시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용 에서 restage를 켜세요."
      en="One time only:
  Moving windows needs Accessibility permission.
  Click the menu bar icon and follow the prompt, or turn restage on in
  System Settings > Privacy & Security > Accessibility." ;;
    how_to_use)
      ko="쓰는 법:
  메뉴바 아이콘 > \"현재 창 배치로 새로 만들기\"
  창을 원하는 대로 놓고 누르면 그 배치가 저장됩니다."
      en="How to use it:
  Menu bar icon > \"New from Current Layout\"
  Arrange your windows, press it, and that layout is saved." ;;
    from_terminal)
      ko="터미널에서도 됩니다:
  restage new 작업이름
  restage open 작업이름"
      en="It works from the terminal too:
  restage new somename
  restage open somename" ;;
    *)
      ko="$1"
      en="$1" ;;
  esac
  if [ "$LANGUAGE" = "ko" ]; then printf '%s\n' "$ko"; else printf '%s\n' "$en"; fi
}

say() { printf "\033[1m%s\033[0m\n" "$1"; }
fail() { printf "\033[31m%s\033[0m\n" "$1" >&2; exit 1; }

# 1. 이 맥에서 돌아가는지
[ "$(uname -s)" = "Darwin" ] || fail "$(t need_macos)"
MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
[ "$MAJOR" -ge "$MIN_MACOS" ] \
  || fail "$(t need_macos_version "$(sw_vers -productVersion)")"

# 2. Swift 컴파일러
#
# Xcode 명령줄 도구가 없으면 설치 창을 띄운다. 그 설치는 사용자가 눌러야 끝나므로
# 여기서 기다리지 않고 안내만 하고 멈춘다.
if ! xcode-select -p >/dev/null 2>&1; then
  say "$(t need_clt)"
  xcode-select --install >/dev/null 2>&1 || true
  fail "$(t need_clt_after)"
fi
command -v swift >/dev/null 2>&1 || fail "$(t no_swift)"

# 3. 소스 받기
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

say "$(t fetching)"
TAG="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)"

if [ -n "$TAG" ]; then
  URL="https://github.com/$REPO/archive/refs/tags/$TAG.tar.gz"
  say "$(t version "$TAG")"
else
  URL="https://github.com/$REPO/archive/refs/heads/main.tar.gz"
  say "$(t latest_source)"
fi

curl -fsSL "$URL" -o "$WORK/src.tar.gz" || fail "$(t fetch_failed)"
tar -xzf "$WORK/src.tar.gz" -C "$WORK"
SRC="$(find "$WORK" -maxdepth 1 -type d -name 'restage-*' | head -1)"
[ -n "$SRC" ] || fail "$(t bad_archive)"

# 4. 빌드
say "$(t building)"
# 빌드 로그는 실패했을 때만 보여준다. 성공했을 때 컴파일 진행 줄이 쏟아지면
# 무엇을 해야 하는지 적어둔 안내가 묻힌다.
BUILD_LOG="$WORK/build.log"
if ! ( cd "$SRC" && ./scripts/make-app.sh "$SRC/build/restage.app" ) >"$BUILD_LOG" 2>&1; then
  tail -30 "$BUILD_LOG" >&2
  fail "$(t build_failed)"
fi

# 5. 설치
say "$(t installing)"
if [ -w "$APP_DIR" ]; then
  rm -rf "${APP_DIR:?}/restage.app"
  cp -R "$SRC/build/restage.app" "$APP_DIR/"
else
  sudo rm -rf "${APP_DIR:?}/restage.app"
  sudo cp -R "$SRC/build/restage.app" "$APP_DIR/"
fi

# 터미널에서도 쓸 수 있게 이어준다. 실패해도 앱은 이미 설치됐으므로 멈추지 않는다.
LINK_NOTE=""
if [ -d "$BIN_DIR" ]; then
  if [ -w "$BIN_DIR" ]; then
    ln -sf "$APP_DIR/restage.app/Contents/MacOS/restage" "$BIN_DIR/restage"
  else
    sudo ln -sf "$APP_DIR/restage.app/Contents/MacOS/restage" "$BIN_DIR/restage" \
      || LINK_NOTE="$(t link_failed)"
  fi
else
  LINK_NOTE="$(t no_bin_dir "$BIN_DIR")"
fi

open "$APP_DIR/restage.app"

cat <<EOF

$(say "$(t installed)")
$LINK_NOTE
$(t menubar_note)

$(t first_time)

$(t how_to_use)

$(t from_terminal)

EOF
