import CoreGraphics

public enum PlacementResult: Sendable {
    /// 목표 좌표에 도달했다. warnings가 비어있지 않으면 주의가 필요하지만 실패는 아니다.
    case ok(actual: CGRect, attempts: Int, elapsed: Duration, warnings: [String])

    /// 앱의 최소 크기 제약 때문에 목표에 도달할 수 없다. 통과로 취급한다.
    case constrained(actual: CGRect, expected: CGRect, minSize: CGSize)

    /// 도달하지 못했고 원인이 최소 크기 제약이 아니다.
    case failed(expected: CGRect, actual: CGRect?, reason: String)

    public var isPass: Bool {
        switch self {
        case .ok, .constrained: return true
        case .failed: return false
        }
    }

    public var label: String {
        switch self {
        case .ok(_, _, _, let warnings): return warnings.isEmpty ? "PASS" : "WARN"
        case .constrained: return "CONSTRAINED"
        case .failed: return "FAIL"
        }
    }
}
