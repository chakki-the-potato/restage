# restage Homebrew 수식.
#
# 소스에서 빌드한다. 미리 빌드한 앱을 나눠주려면 Developer ID 인증서로 서명하고
# 공증해야 하는데 유료 계정이 필요하다. 받는 사람이 직접 빌드하면 그 과정이 필요 없고
# Gatekeeper 경고도 뜨지 않는다.
#
# Homebrew를 쓰는 사람은 이미 Xcode 명령줄 도구를 갖고 있으므로 Swift 컴파일러가 있다.
class Restage < Formula
  desc "미리 선언한 앱과 창 배치를 한 번에 복원하는 macOS 도구"
  homepage "https://github.com/chakki-the-potato/restage"
  url "https://github.com/chakki-the-potato/restage/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "d37aaf8b32269f47b172f93f106d08e87561c1e384dc9d90c7a65773097c70d3"
  license "MIT"
  head "https://github.com/chakki-the-potato/restage.git", branch: "main"

  depends_on macos: :ventura
  depends_on xcode: :build

  def install
    # Homebrew는 이미 샌드박스 안에서 빌드한다. SwiftPM이 자기 샌드박스를 또 걸면
    # sandbox_apply가 거부되어 매니페스트 컴파일부터 실패한다.
    ENV["RESTAGE_SWIFT_FLAGS"] = "--disable-sandbox"

    # 메뉴바 앱은 번들이어야 한다. SMAppService가 번들을 요구하고, Finder에서 여는
    # 경로도 번들이어야 열린다.
    system "./scripts/make-app.sh", buildpath/"build/restage.app"

    prefix.install "build/restage.app"
    bin.install_symlink prefix/"restage.app/Contents/MacOS/restage"
  end

  def caveats
    <<~EOS
      메뉴바 앱을 열려면:
        open #{opt_prefix}/restage.app

      로그인할 때 자동으로 뜨게 하려면 앱을 연 뒤 Options에서 켜세요.

      창을 옮기려면 접근성 권한이 필요합니다. 앱을 처음 열면 안내가 뜹니다.
        시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용

      터미널에서 쓰려면:
        restage new 작업이름     지금 창 배치로 워크스페이스 만들기
        restage open 작업이름    복원하기
        restage list            목록 보기

      다른 데스크탑에 있는 창까지 다루려면 이 설정을 켜세요:
        시스템 설정 > 데스크탑 및 Dock >
        "응용 프로그램으로 전환할 때, 해당 앱의 열린 윈도우가 있는 공간으로 전환"

      업그레이드하면 접근성 권한을 다시 켜야 할 수 있습니다. 무료 서명은 빌드마다
      신원이 바뀌기 때문입니다.
    EOS
  end

  test do
    assert_match "restage", shell_output("#{bin}/restage 2>&1", 2)
  end
end
