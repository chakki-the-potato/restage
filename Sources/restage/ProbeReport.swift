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
        case .constrained(let actual, let expected, let minSize):
            return ProbeRow(
                app: app.rawValue, start: start, label: result.label,
                expected: expected, actual: actual, attempts: nil, elapsedMS: nil,
                note: "최소 크기 \(fmt(minSize))")
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
        var lines: [String] = []
        lines.append(
            pad("APP", 12) + pad("START", 8) + pad("RESULT", 13)
            + pad("EXPECTED", 23) + pad("ACTUAL", 23)
            + padLeft("TRY", 4) + padLeft("MS", 8) + "  NOTE")
        lines.append(String(repeating: "-", count: 110))

        for row in rows {
            lines.append(
                pad(row.app, 12) + pad(row.start, 8) + pad(row.label, 13)
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

    static func hasFailure(_ rows: [ProbeRow]) -> Bool {
        rows.contains { $0.label == "FAIL" }
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

    private static func fmt(_ size: CGSize) -> String {
        String(format: "%.0fx%.0f", size.width, size.height)
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        let components = duration.components
        return Int(components.seconds) * 1000
            + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}
