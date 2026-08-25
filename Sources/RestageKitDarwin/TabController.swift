import Foundation
import RestageKit

struct BrowserWindow {
    let id: Int
    let tabURLs: [String]
}

@MainActor
enum TabController {
    static let windowAppearTimeout: Duration = .seconds(5)

    struct Result {
        let openedCount: Int
        let windowID: Int
    }

    static func apply(_ plan: TabPlan, dialect: BrowserDialect) async throws -> Result {
        guard let first = plan.tabs.first else {
            throw AppleScriptError.executionFailed(code: 0, message: L10n.string("error.tabs.empty"))
        }

        let windowID: Int
        switch plan.window {
        case .separate:
            windowID = try await resolveDedicatedWindow(firstURL: first, dialect: dialect)
        case .shared:
            windowID = try resolveFrontWindow(firstURL: first, dialect: dialect)
        }

        let existing = Set(try windows(dialect: dialect)
            .first { $0.id == windowID }?
            .tabURLs.map(URLNormalizer.normalize) ?? [])

        var opened = 0
        for url in plan.tabs where !existing.contains(url) {
            _ = try AppleScriptRunner.run(
                dialect.addTabScript(windowID: windowID, url: url),
                applicationName: dialect.applicationName)
            opened += 1
        }
        return Result(openedCount: opened, windowID: windowID)
    }

    private static func resolveDedicatedWindow(
        firstURL: String, dialect: BrowserDialect
    ) async throws -> Int {
        if let found = try findWindow(firstURL: firstURL, dialect: dialect) { return found }

        _ = try AppleScriptRunner.run(
            dialect.newWindowScript(url: firstURL),
            applicationName: dialect.applicationName)

        let appeared = await Polling.poll(timeout: windowAppearTimeout) {
            (try? findWindow(firstURL: firstURL, dialect: dialect)) ?? nil
        }
        guard let appeared else {
            throw AppleScriptError.executionFailed(
                code: 0, message: L10n.string("error.tabs.no_new_window"))
        }
        return appeared
    }

    private static func resolveFrontWindow(
        firstURL: String, dialect: BrowserDialect
    ) throws -> Int {
        let raw = try AppleScriptRunner.run(
            dialect.frontWindowIDScript(), applicationName: dialect.applicationName)
        if let id = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) { return id }

        _ = try AppleScriptRunner.run(
            dialect.newWindowScript(url: firstURL),
            applicationName: dialect.applicationName)
        let retry = try AppleScriptRunner.run(
            dialect.frontWindowIDScript(), applicationName: dialect.applicationName)
        guard let id = Int(retry.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw AppleScriptError.executionFailed(code: 0, message: L10n.string("error.tabs.window_not_found"))
        }
        return id
    }

    private static func findWindow(firstURL: String, dialect: BrowserDialect) throws -> Int? {
        try windows(dialect: dialect).first {
            guard let first = $0.tabURLs.first else { return false }
            return URLNormalizer.normalize(first) == firstURL
        }?.id
    }

    private static func windows(dialect: BrowserDialect) throws -> [BrowserWindow] {
        let raw = try AppleScriptRunner.run(
            dialect.readWindowsScript(), applicationName: dialect.applicationName)
        return raw.split(separator: "\n").compactMap { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard let id = Int(fields.first ?? "") else { return nil }
            return BrowserWindow(id: id, tabURLs: fields.dropFirst().map(String.init))
        }
    }
}
