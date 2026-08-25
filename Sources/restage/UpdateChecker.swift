import Foundation
import RestageKit

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
