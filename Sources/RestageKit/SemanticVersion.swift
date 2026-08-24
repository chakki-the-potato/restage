/// `v0.1.0` 같은 버전 문자열을 비교 가능한 형태로 만든다.
///
/// 문자열 비교로는 안 된다. "0.10.0" < "0.9.0"이 되어 새 버전을 놓친다.
public struct SemanticVersion: Comparable, Equatable, Sendable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// 앞의 `v`와 뒤에 붙은 표식(`-beta.1` 등)은 무시한다. 숫자가 하나도 없으면 nil이다.
    public init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        if let marker = text.firstIndex(where: { $0 == "-" || $0 == "+" }) {
            text = String(text[text.startIndex..<marker])
        }

        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard let first = parts.first, let major = Int(first) else { return nil }
        func number(_ index: Int) -> Int {
            guard parts.indices.contains(index), let value = Int(parts[index]) else { return 0 }
            return value
        }
        self.init(major: major, minor: number(1), patch: number(2))
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}
