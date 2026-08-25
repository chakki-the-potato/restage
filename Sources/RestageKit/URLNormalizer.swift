import Foundation

public enum URLNormalizer {
    private static let defaultScheme = "https://"

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
