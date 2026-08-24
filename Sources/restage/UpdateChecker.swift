import Foundation
import RestageKit

/// GitHub Releases에서 최신 버전을 확인한다.
///
/// Sparkle 같은 자동 업데이트 프레임워크를 쓰지 않는 이유는 그것이 서명된 appcast와
/// 배포 서버를 요구하기 때문이다. 이 도구는 소스를 받아 각자 빌드하는 방식이라 새 버전이
/// 있다는 사실만 알려주면 된다. 받는 것은 사용자가 GitHub에서 한다.
///
/// 사용자가 누를 때만 확인한다. 주기적으로 부르지 않는 이유는 도구를 쓰는 데 네트워크가
/// 필요 없어야 하기 때문이다.
enum UpdateChecker {
    enum Result {
        case upToDate(SemanticVersion)
        case available(latest: SemanticVersion, url: String)
        case failed(String)
    }

    private static let endpoint =
        "https://api.github.com/repos/chakki-the-potato/restage/releases/latest"
    private static let timeout: TimeInterval = 10

    static func check(current raw: String) async -> Result {
        guard let current = SemanticVersion(raw) else {
            return .failed(L10n.string("error.update.bad_current", raw))
        }
        guard let url = URL(string: endpoint) else {
            return .failed(L10n.string("error.update.bad_url"))
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 404 {
                return .failed(L10n.string("error.update.no_release"))
            }
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                return .failed(L10n.string("error.update.bad_response", Int(code)))
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = json["tag_name"] as? String,
                  let latest = SemanticVersion(tag) else {
                return .failed(L10n.string("error.update.no_version"))
            }

            guard latest > current else { return .upToDate(current) }
            let page = (json["html_url"] as? String)
                ?? "https://github.com/chakki-the-potato/restage/releases"
            return .available(latest: latest, url: page)
        } catch {
            return .failed(L10n.string("error.update.failed", error.localizedDescription))
        }
    }
}
