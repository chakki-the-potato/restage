public enum WindowIdentity {
    public struct Candidate: Sendable, Equatable {
        public let app: String
        public let title: String

        public init(app: String, title: String) {
            self.app = app
            self.title = title
        }
    }

    public struct Selection: Sendable, Equatable {
        public let kept: [Int]
        public let needsTitle: Set<Int>
        public let byOrderByApp: [String: Int]
    }

    private static let titleSeparators = [" — ", " – ", " - "]

    public static func stableTitle(_ title: String) -> String {
        for separator in titleSeparators {
            if let range = title.range(of: separator, options: .backwards) {
                let tail = title[range.upperBound...].trimmingCharacters(in: .whitespaces)
                if !tail.isEmpty { return tail }
            }
        }
        return title
    }

    public static func select(_ candidates: [Candidate]) -> Selection {
        var indicesByApp: [String: [Int]] = [:]
        for (index, candidate) in candidates.enumerated() {
            indicesByApp[candidate.app, default: []].append(index)
        }

        var needsTitle: Set<Int> = []
        var byOrder: [String: Int] = [:]

        for (app, indices) in indicesByApp where indices.count > 1 {
            var titleCounts: [String: Int] = [:]
            for index in indices {
                titleCounts[candidates[index].title, default: 0] += 1
            }
            let identifiable = indices.filter { index in
                let title = candidates[index].title
                return !title.isEmpty && titleCounts[title] == 1
            }
            needsTitle.formUnion(identifiable)
            let unnamed = indices.count - identifiable.count
            if unnamed > 0 { byOrder[app] = unnamed }
        }

        return Selection(
            kept: Array(candidates.indices),
            needsTitle: needsTitle,
            byOrderByApp: byOrder)
    }
}
