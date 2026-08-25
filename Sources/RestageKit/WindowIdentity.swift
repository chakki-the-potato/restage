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
        public let droppedByApp: [String: Int]
    }

    public static func select(_ candidates: [Candidate]) -> Selection {
        var indicesByApp: [String: [Int]] = [:]
        for (index, candidate) in candidates.enumerated() {
            indicesByApp[candidate.app, default: []].append(index)
        }

        var kept: Set<Int> = []
        var needsTitle: Set<Int> = []
        var dropped: [String: Int] = [:]

        for (app, indices) in indicesByApp {
            guard indices.count > 1 else {
                kept.formUnion(indices)
                continue
            }

            var titleCounts: [String: Int] = [:]
            for index in indices {
                titleCounts[candidates[index].title, default: 0] += 1
            }
            let identifiable = indices.filter { index in
                let title = candidates[index].title
                return !title.isEmpty && titleCounts[title] == 1
            }

            if identifiable.count == indices.count {
                kept.formUnion(indices)
                needsTitle.formUnion(indices)
            } else if identifiable.isEmpty {
                kept.insert(indices[0])
                dropped[app] = indices.count - 1
            } else {
                kept.formUnion(identifiable)
                needsTitle.formUnion(identifiable)
                dropped[app] = indices.count - identifiable.count
            }
        }

        return Selection(
            kept: candidates.indices.filter { kept.contains($0) },
            needsTitle: needsTitle,
            droppedByApp: dropped)
    }
}
