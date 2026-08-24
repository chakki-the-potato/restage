import CoreGraphics
import Foundation
import RestageKit

enum RunReport {
    static func render(workspace: String, outcomes: [ItemOutcome]) -> String {
        let screens = ["SCREEN"] + outcomes.map(\.screenID)
        let apps = ["APP"] + outcomes.map { $0.app?.rawValue ?? "-" }
        let screenWidth = width(of: screens)
        let appWidth = width(of: apps)

        var lines: [String] = [L10n.string("cli.report.workspace", workspace), ""]
        lines.append(
            pad("SCREEN", screenWidth) + pad("APP", appWidth) + pad("RESULT", 18)
            + pad("EXPECTED", 23) + pad("ACTUAL", 23) + "NOTE")
        lines.append(String(repeating: "-", count: screenWidth + appWidth + 70))

        for outcome in outcomes {
            lines.append(
                pad(outcome.screenID, screenWidth) + pad(outcome.app?.rawValue ?? "-", appWidth)
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
        let verdict = failures.isEmpty
            ? L10n.string("cli.report.done")
            : L10n.string("cli.report.done_with_failures", failures.count)
        return L10n.string(
            "cli.report.tally", parts.joined(separator: " / "), outcomes.count, verdict)
    }

    static func hasFailure(_ outcomes: [ItemOutcome]) -> Bool {
        outcomes.contains { !$0.status.isSuccess }
    }

    /// 열 너비를 내용에 맞춘다. 앱 이름은 사용자 컴퓨터에서 오는 값이라
    /// "Google Chrome"이나 "Microsoft PowerPoint"처럼 길 수 있다.
    private static func width(of values: [String]) -> Int {
        (values.map(\.count).max() ?? 0) + 2
    }

    /// 열 너비를 넘는 값이 와도 최소 한 칸은 띄운다. 그러지 않으면 긴 앱 이름 뒤에
    /// 다음 열이 붙어 표가 깨진다.
    private static func pad(_ text: String, _ width: Int) -> String {
        let padding = max(1, width - text.count)
        return text + String(repeating: " ", count: padding)
    }

    private static func format(_ rect: CGRect) -> String {
        String(format: "%.0f,%.0f %.0fx%.0f", rect.minX, rect.minY, rect.width, rect.height)
    }
}
