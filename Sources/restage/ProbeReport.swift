import CoreGraphics
import Foundation
import RestageKit

struct ProbeRow {
    let app: String
    let start: String
    let label: String
    let expected: CGRect?
    let actual: CGRect?
    let attempts: Int?
    let elapsedMS: Int?
    let note: String
}

enum ProbeReport {
    static func row(app: AppID, start: String, result: PlacementResult) -> ProbeRow {
        switch result {
        case .ok(let actual, let attempts, let elapsed, let warnings):
            return ProbeRow(
                app: app.rawValue, start: start, label: result.label,
                expected: nil, actual: actual, attempts: attempts,
                elapsedMS: milliseconds(elapsed), note: warnings.joined(separator: "; "))
        case .constrained(let actual, let expected, let reason):
            return ProbeRow(
                app: app.rawValue, start: start, label: result.label,
                expected: expected, actual: actual, attempts: nil, elapsedMS: nil,
                note: reason)
        case .failed(let expected, let actual, let reason):
            return ProbeRow(
                app: app.rawValue, start: start, label: result.label,
                expected: expected, actual: actual, attempts: nil, elapsedMS: nil,
                note: reason)
        }
    }

    static func errorRow(app: AppID, start: String, error: Error) -> ProbeRow {
        ProbeRow(
            app: app.rawValue, start: start, label: "FAIL",
            expected: nil, actual: nil, attempts: nil, elapsedMS: nil,
            note: String(describing: error))
    }

    static func render(_ rows: [ProbeRow]) -> String {
        let appWidth = width(of: ["APP"] + rows.map(\.app))
        var lines: [String] = []
        lines.append(
            pad("APP", appWidth) + pad("START", 8) + pad("RESULT", 13)
            + pad("EXPECTED", 23) + pad("ACTUAL", 23)
            + padLeft("TRY", 4) + padLeft("MS", 8) + "  NOTE")
        lines.append(String(repeating: "-", count: 110))

        for row in rows {
            lines.append(
                pad(row.app, appWidth) + pad(row.start, 8) + pad(row.label, 13)
                + pad(row.expected.map(fmt) ?? "-", 23)
                + pad(row.actual.map(fmt) ?? "-", 23)
                + padLeft(row.attempts.map(String.init) ?? "-", 4)
                + padLeft(row.elapsedMS.map(String.init) ?? "-", 8)
                + "  " + row.note)
        }

        lines.append("")
        lines.append(summary(rows))
        return lines.joined(separator: "\n")
    }

    static func summary(_ rows: [ProbeRow]) -> String {
        let counts = Dictionary(grouping: rows, by: \.label).mapValues(\.count)
        let order = ["PASS", "WARN", "CONSTRAINED", "FAIL"]
        let parts = order.compactMap { key -> String? in
            guard let count = counts[key] else { return nil }
            return "\(key) \(count)"
        }
        let failed = counts["FAIL"] ?? 0
        let verdict = failed == 0 ? "GATE PASSED" : "GATE FAILED"
        return "\(parts.joined(separator: " / "))  총 \(rows.count)건 — \(verdict)"
    }

    /// 전체화면 해제 실패를 표시한다. 전환 자체의 판정은 유지하고 경고만 붙인다.
    ///
    /// 실패로 뒤집지 않는 이유는 이것이 구현 결함이 아니라 플랫폼 한계이기 때문이다.
    /// 앱이 전체화면이 되면 전용 Space로 옮겨지는데, 화면은 그 Space로 전환되지 않고
    /// AX는 다른 Space의 창을 열거하지 못한다. 그래서 해제할 창에 도달할 방법이 없다.
    /// 사용자가 직접 `ctrl+cmd+F`로 빠져나와야 한다.
    static func markRestoreFailure(_ row: ProbeRow) -> ProbeRow {
        ProbeRow(
            app: row.app, start: row.start,
            label: row.label == "PASS" ? "WARN" : row.label,
            expected: row.expected, actual: row.actual,
            attempts: row.attempts, elapsedMS: row.elapsedMS,
            note: "해제 불가, Space 잔류 (수동 해제 필요). \(row.note)")
    }

    static func hasFailure(_ rows: [ProbeRow]) -> Bool {
        rows.contains { $0.label == "FAIL" }
    }

    /// 열 너비를 내용에 맞춘다. 앱 이름은 사용자 컴퓨터에서 오는 값이라 길 수 있다.
    private static func width(of values: [String]) -> Int {
        (values.map(\.count).max() ?? 0) + 2
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : text + String(repeating: " ", count: width - text.count)
    }

    private static func padLeft(_ text: String, _ width: Int) -> String {
        text.count >= width ? text : String(repeating: " ", count: width - text.count) + text
    }

    private static func fmt(_ rect: CGRect) -> String {
        String(format: "%.0f,%.0f %.0fx%.0f", rect.minX, rect.minY, rect.width, rect.height)
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        let components = duration.components
        return Int(components.seconds) * 1000
            + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}
