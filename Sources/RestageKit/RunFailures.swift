public enum RunFailures {
    public static func summary(_ outcomes: [ItemOutcome]) -> String? {
        let failures = outcomes.filter { !$0.status.isSuccess }
        guard !failures.isEmpty else { return nil }
        return failures.map { outcome in
            let app = outcome.app?.rawValue ?? outcome.screenID
            return "\(app): \(outcome.detail)"
        }.joined(separator: "\n")
    }
}
