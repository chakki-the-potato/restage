import CoreGraphics

public enum OutcomeStatus: String, Sendable {
    /// 배치했다.
    case placed
    /// 이미 목표 상태여서 건드리지 않았다. 멱등성의 핵심이다.
    case alreadySatisfied
    /// 앱이 막았다. 최소 크기, 크기 고정, 전체화면 미지원.
    case constrained
    /// 창이 다른 Space에 있어 접근할 수 없다.
    case unreachable
    /// 그 외 실패. 앱 미설치, 실행 실패, 창 미등장.
    case failed
    /// 미구현 기능이거나 건너뛴 화면.
    case skipped

    /// `constrained`를 성공으로 세는 이유는 고칠 수 없는 앱 동작이기 때문이다.
    /// `unreachable`을 실패로 세는 이유는 사용자가 해당 Space로 이동하면 해소되기 때문이다.
    public var isSuccess: Bool {
        switch self {
        case .placed, .alreadySatisfied, .constrained: return true
        case .unreachable, .failed, .skipped: return false
        }
    }
}

public struct ItemOutcome: Sendable {
    public let screenID: String
    /// 화면 단위로 건너뛴 경우에는 앱이 없다.
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
