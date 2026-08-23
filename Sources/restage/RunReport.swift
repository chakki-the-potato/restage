import CoreGraphics
import Foundation
import RestageKit

enum RunReport {
    static func render(workspace: String, outcomes: [ItemOutcome]) -> String {
        var lines: [String] = ["워크스페이스: \(workspace)", ""]
        lines.append(
            pad("SCREEN", 12) + pad("APP", 12) + pad("RESULT", 18)
            + pad("EXPECTED", 23) + pad("ACTUAL", 23) + "NOTE")
        lines.append(String(repeating: "-", count: 110))

        for outcome in outcomes {
            lines.append(
                pad(outcome.screenID, 12) + pad(outcome.app?.rawValue ?? "-", 12)
                + pad(outcome.status.rawValue, 18)
                + pad(outcome.expected.map(format) ?? "-", 23)
                + pad(outcome.actual.map(format) ?? "-", 23)
                + outcome.detail)
        }

        lines.append("")
        lines.append(summary(outcomes))
        return lines.joined(separator: "\n")
    }

    static func summary(_ outcomes: [ItemOutcome]) -> String {
        let counts = Dictionary(grouping: outcomes, by: \.status.rawValue).mapValues(\.count)
        let order = ["placed", "alreadySatisfied", "constrained", "unreachable", "failed", "skipped"]
        let parts = order.compactMap { key -> String? in
            guard let count = counts[key] else { return nil }
            return "\(key) \(count)"
        }
        let failures = outcomes.filter { !$0.status.isSuccess }
        let verdict = failures.isEmpty ? "완료" : "완료 (실패 \(failures.count)건)"
        return "\(parts.joined(separator: " / "))  총 \(outcomes.count)건 — \(verdict)"
    }

    static func hasFailure(_ outcomes: [ItemOutcome]) -> Bool {
        outcomes.contains { !$0.status.isSuccess }
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }

    private static func format(_ rect: CGRect) -> String {
        String(format: "%.0f,%.0f %.0fx%.0f", rect.minX, rect.minY, rect.width, rect.height)
    }
}
