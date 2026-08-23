import Foundation

/// 브라우저가 돌려주는 URL과 config에 적힌 URL을 비교 가능한 형태로 맞춘다.
///
/// 브라우저는 `https://example.com`을 `https://example.com/`으로 돌려주고,
/// config에는 스킴 없이 `example.com`이라고 적을 수 있다. 이 차이를 흡수하지 않으면
/// 이미 열린 탭을 없는 것으로 보고 매번 중복해서 연다.
public enum URLNormalizer {
    private static let defaultScheme = "https://"

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
