import CoreGraphics
import Foundation
import RestageKit

public struct CapturedBrowserWindow: Sendable, Equatable {
    public let frame: CGRect
    public let tabs: [String]

    public init(frame: CGRect, tabs: [String]) {
        self.frame = frame
        self.tabs = tabs
    }
}

@MainActor
public enum BrowserSnapshot {
    public nonisolated static let defaultTolerance: CGFloat = 2

    public static func windows(of app: AppID) throws -> [CapturedBrowserWindow] {
        let dialect = try BrowserDialect.forApp(app)
        let raw = try AppleScriptRunner.run(
            dialect.readWindowGeometryScript(), applicationName: dialect.applicationName)
        return parse(raw)
    }

    public nonisolated static func index(
        matching frame: CGRect, in windows: [CapturedBrowserWindow],
        tolerance: CGFloat = defaultTolerance
    ) -> Int? {
        windows.firstIndex { candidate in
            abs(candidate.frame.minX - frame.minX) <= tolerance
                && abs(candidate.frame.minY - frame.minY) <= tolerance
                && abs(candidate.frame.width - frame.width) <= tolerance
                && abs(candidate.frame.height - frame.height) <= tolerance
        }
    }

    public static func isBrowser(_ app: AppID) -> Bool {
        (try? BrowserDialect.forApp(app)) != nil
    }

    nonisolated static func parse(_ raw: String) -> [CapturedBrowserWindow] {
        raw.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 4 else { return nil }
            let edges = fields.prefix(4).compactMap {
                Double($0.trimmingCharacters(in: .whitespaces))
            }
            guard edges.count == 4 else { return nil }
            let frame = CGRect(
                x: edges[0], y: edges[1],
                width: edges[2] - edges[0], height: edges[3] - edges[1])
            return CapturedBrowserWindow(frame: frame, tabs: fields.dropFirst(4).map(String.init))
        }
    }
}
