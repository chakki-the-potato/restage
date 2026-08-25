# restage Homebrew cask.
#
# 수식(Formula)과 달리 빌드하지 않는다. 릴리스에 올린 dmg를 받아 그대로 넣는다.
# 그래서 Xcode 명령줄 도구가 필요 없고 설치가 몇 초로 끝난다.
#
# 다만 받는 사람의 맥에서 바로 열리려면 그 dmg가 Developer ID로 서명되고 공증되어
# 있어야 한다. 공증에는 유료 Apple Developer Program이 필요하다. 그 전까지 이 cask로
# 설치하면 첫 실행에 우클릭 열기가 필요하므로, README는 수식 쪽을 안내한다.
cask "restage" do
  version "0.4.2"
  sha256 :no_check

  url "https://github.com/chakki-the-potato/restage/releases/download/v#{version}/restage-#{version}.dmg",
      verified: "github.com/chakki-the-potato/restage/"
  name "restage"
  desc "Restore a declared layout of apps and windows in one step"
  homepage "https://github.com/chakki-the-potato/restage"

  depends_on macos: :ventura

  app "restage.app"

  # 워크스페이스 config는 사용자가 만든 것이므로 지우지 않는다.
  zap trash: [
    "~/Library/Preferences/com.chakki.restage.plist",
  ]

  caveats <<~EOS
    창을 옮기려면 접근성 권한이 필요합니다. 앱을 처음 열면 안내가 뜹니다.
      시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용

    다른 데스크탑에 있는 창까지 다루려면 이 설정을 켜세요.
      시스템 설정 > 데스크탑 및 Dock >
      "응용 프로그램으로 전환할 때, 해당 앱의 열린 윈도우가 있는 공간으로 전환"
  EOS
end
