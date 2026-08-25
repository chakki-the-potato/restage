import Foundation

/// 이 앱이 어떻게 설치됐는지.
///
/// 업데이트하는 방법이 설치 경로마다 다르다. Homebrew로 깐 사람에게 릴리스 페이지를
/// 열어 주면 받은 앱을 직접 덮어쓰게 되고, 그러면 brew가 아는 상태와 실제가 어긋난다.
/// 다음 `brew upgrade`가 무엇을 지웠는지 알 수 없게 된다.
enum InstallSource {
    case homebrew
    case elsewhere

    /// Homebrew 수식은 앱을 Cellar 아래에 두고 opt로 심볼릭 링크를 건다. 링크를 풀어
    /// 실제 경로를 본다.
    static var current: InstallSource {
        from(path: Bundle.main.bundleURL.resolvingSymlinksInPath().path)
    }

    static func from(path: String) -> InstallSource {
        path.contains("/Cellar/restage/") ? .homebrew : .elsewhere
    }

    static let formula = "chakki-the-potato/tap/restage"
}
