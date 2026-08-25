import CoreGraphics

public enum PlacementResult: Sendable {
    case ok(actual: CGRect, attempts: Int, elapsed: Duration, warnings: [String])

    case constrained(actual: CGRect, expected: CGRect, reason: String)

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
