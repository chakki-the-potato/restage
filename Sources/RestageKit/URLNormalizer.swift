import Foundation

/// 브라우저가 돌려주는 URL과 config에 적힌 URL을 비교 가능한 형태로 맞춘다.
///
/// 브라우저는 `https://example.com`을 `https://example.com/`으로 돌려주고,
/// config에는 스킴 없이 `example.com`이라고 적을 수 있다. 이 차이를 흡수하지 않으면
/// 이미 열린 탭을 없는 것으로 보고 매번 중복해서 연다.
public enum URLNormalizer {
    private static let defaultScheme = "https://"

    /// config에 담을 만한 주소인지.
    ///
    /// 브라우저 내부 페이지는 담지 않는다. Safari의 시작 페이지는 `favorites://`,
    /// Chrome의 새 탭은 `chrome://newtab/`으로 나오는데, 이런 것을 config에 적으면
    /// 나중에 `restage open`이 열 수 없는 주소를 열려고 한다.
    ///
    /// 스킴이 없으면 담는다. 사용자가 `example.com`이라고 적는 경로를 막지 않기 위해서다.
    public static func isSavable(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        guard let range = trimmed.range(of: "://") else { return !trimmed.contains(":") }
        let scheme = trimmed[trimmed.startIndex..<range.lowerBound].lowercased()
        return scheme == "http" || scheme == "https"
    }

    public static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let withScheme = hasScheme(trimmed) ? trimmed : defaultScheme + trimmed

        guard var components = URLComponents(string: withScheme) else { return withScheme }
        components.host = components.host?.lowercased()

        if components.path.hasSuffix("/"), components.path.count > 1 {
            components.path = String(components.path.dropLast())
        } else if components.path == "/", components.query == nil, components.fragment == nil {
            components.path = ""
        }

        return components.string ?? withScheme
    }

    private static func hasScheme(_ text: String) -> Bool {
        guard let range = text.range(of: "://") else { return false }
        let scheme = text[text.startIndex..<range.lowerBound]
        return !scheme.isEmpty
            && scheme.allSatisfy { $0.isLetter || $0.isNumber || $0 == "+" || $0 == "-" || $0 == "." }
    }
}
