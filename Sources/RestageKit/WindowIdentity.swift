/// 한 앱의 창 여럿 중에서 config에 담을 수 있는 것을 고른다.
///
/// 창을 골라내는 수단은 제목뿐이다. 제목이 비었거나 두 창이 같은 제목을 쓰면 실행할 때
/// 어느 창인지 정할 수 없고, 결국 매번 같은 창이 잡혀 나머지는 영영 배치되지 않는다.
/// 그런 항목을 조용히 담으면 사용자는 담긴 줄 알지만 실제로는 동작하지 않는다.
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
        /// 담을 창의 인덱스. 입력 순서를 유지한다.
        public let kept: [Int]
        /// 제목으로 골라낼 수 있어 `title`을 적어야 하는 인덱스.
        public let needsTitle: Set<Int>
        /// 구분할 수 없어 버린 창의 개수. 앱 이름별로 센다.
        public let droppedByApp: [String: Int]
    }

    /// 규칙은 셋이다.
    ///
    /// - 창이 하나뿐이면 그대로 담는다. 제목은 바뀌기 쉬우므로 굳이 적지 않는다.
    /// - 창이 여럿이고 전부 고유한 제목을 가지면 전부 담고 제목을 적는다.
    /// - 그 밖에는 고유한 제목을 가진 것만 담는다. 하나도 없으면 첫 창 하나만 담는다.
    ///   전부 버리면 그 앱이 통째로 사라져 사용자가 더 놀란다.
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
