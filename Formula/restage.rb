# restage Homebrew 수식.
#
# 소스에서 빌드한다. 미리 빌드한 앱을 나눠주려면 Developer ID 인증서로 서명하고
# 공증해야 하는데 유료 계정이 필요하다. 받는 사람이 직접 빌드하면 그 과정이 필요 없고
# Gatekeeper 경고도 뜨지 않는다.
#
# Homebrew를 쓰는 사람은 이미 Xcode 명령줄 도구를 갖고 있으므로 Swift 컴파일러가 있다.
class Restage < Formula
  desc "Restore a declared layout of apps and windows in one step"
  homepage "https://github.com/chakki-the-potato/restage"
  url "https://github.com/chakki-the-potato/restage/archive/refs/tags/v0.5.0.tar.gz"
  sha256 "55f0f36f2109562b70d69951b45b99d50826b33e91501eba652e1f5ae37259bf"
  license "MIT"
  head "https://github.com/chakki-the-potato/restage.git", branch: "main"

  depends_on macos: :ventura
  depends_on xcode: :build

  def install
    # Homebrew는 이미 샌드박스 안에서 빌드한다. SwiftPM이 자기 샌드박스를 또 걸면
    # sandbox_apply가 거부되어 매니페스트 컴파일부터 실패한다.
    ENV["RESTAGE_SWIFT_FLAGS"] = "--disable-sandbox"

    # 앱에 박을 버전을 넘긴다. 넘기지 않으면 앱이 자기 버전을 모르고, 업데이트 확인이
    # 방금 설치한 것에도 새 버전이 있다고 답한다.
    ENV["RESTAGE_VERSION"] = version.to_s

    # 메뉴바 앱은 번들이어야 한다. SMAppService가 번들을 요구하고, Finder에서 여는
    # 경로도 번들이어야 열린다.
    system "./scripts/make-app.sh", buildpath/"build/restage.app"

    prefix.install "build/restage.app"
    bin.install_symlink prefix/"restage.app/Contents/MacOS/restage"
  end

  def caveats
    <<~EOS
      To open the menu bar app:
        open #{opt_prefix}/restage.app

      To have it start at login, open the app and turn it on under the gear.

      Moving windows needs Accessibility permission. The app asks the first
      time you open it.
        System Settings > Privacy & Security > Accessibility

      From the terminal:
        restage new somename     save the current window layout
        restage open somename    restore it
        restage list             list what you saved

      To reach windows on other desktops, turn this on:
        System Settings > Desktop & Dock >
        "When switching to an application, switch to a Space with open
         windows for the application"

      To update:
        brew upgrade chakki-the-potato/tap/restage
    EOS
  end

  test do
    assert_match "restage", shell_output("#{bin}/restage 2>&1", 2)
  end
end
