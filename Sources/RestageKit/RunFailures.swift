/// 실행 결과에서 실패한 것만 사람이 읽을 형태로 모은다.
///
/// 메뉴바 패널과 터미널이 같은 문장을 보여줘야 하므로 한곳에 둔다.
public enum RunFailures {
    /// 실패가 없으면 nil.
    public static func summary(_ outcomes: [ItemOutcome]) -> String? {
        let failures = outcomes.filter { !$0.status.isSuccess }
        guard !failures.isEmpty else { return nil }
        return failures.map { outcome in
            let app = outcome.app?.rawValue ?? outcome.screenID
            return "\(app): \(outcome.detail)"
        }.joined(separator: "\n")
    }
}
