import Foundation

/// 이 앱이 말하는 자기 버전.
///
/// `Bundle.main`을 그대로 믿을 수 없다. 설치 스크립트와 수식은 `bin/restage`를 앱 번들
/// 안으로 심볼릭 링크하는데, 링크로 실행하면 `Bundle.main`이 링크가 놓인 폴더를 가리켜
/// Info.plist를 찾지 못한다. 그러면 버전이 "dev"로 떨어지고, 업데이트 확인이 방금 설치한
/// 것에도 새 버전이 있다고 답한다.
///
/// 그래서 실행 파일의 링크를 풀어 번들을 다시 찾는다.
enum AppVersion {
    private static let key = "CFBundleShortVersionString"

    /// 번들 밖에서 돌 때는 "dev"다. 저장소에서 `swift run`으로 부른 경우가 그렇다.
    static let current: String = {
        if let version = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return version
        }
        guard let bundle = resolvedBundle(),
              let version = bundle.object(forInfoDictionaryKey: key) as? String
        else { return "dev" }
        return version
    }()

    /// `.../restage.app/Contents/MacOS/restage` 에서 `.../restage.app` 으로 거슬러 오른다.
    private static func resolvedBundle() -> Bundle? {
        guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else {
            return nil
        }
        let url = executable
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return Bundle(url: url)
    }
}
