import CoreGraphics

public enum OutcomeStatus: String, Sendable {
    case placed
    case alreadySatisfied
    case constrained
    case unreachable
    case failed
    case skipped

    public var isSuccess: Bool {
        switch self {
        case .placed, .alreadySatisfied, .constrained: return true
        case .unreachable, .failed, .skipped: return false
        }
    }
}

public struct ItemOutcome: Sendable {
    public let screenID: String
    public let app: AppID?
    public let status: OutcomeStatus
    public let expected: CGRect?
    public let actual: CGRect?
    public let detail: String

    public init(
        screenID: String, app: AppID?, status: OutcomeStatus,
        expected: CGRect? = nil, actual: CGRect? = nil, detail: String = ""
    ) {
        self.screenID = screenID
        self.app = app
        self.status = status
        self.expected = expected
        self.actual = actual
        self.detail = detail
    }
}

extension ItemOutcome {
    public func noting(_ note: String) -> ItemOutcome {
        ItemOutcome(
            screenID: screenID, app: app, status: status, expected: expected, actual: actual,
            detail: detail.isEmpty ? note : note + ". " + detail)
    }
}
