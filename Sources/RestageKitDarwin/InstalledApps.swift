import AppKit
import RestageKit

public struct InstalledApp: Sendable, Equatable {
    public let name: String
    public let bundleID: String
    public let fileName: String

    public init(name: String, bundleID: String, fileName: String) {
        self.name = name
        self.bundleID = bundleID
        self.fileName = fileName
    }
}

@MainActor
public enum InstalledApps {
    private static var cache: [InstalledApp]?

    private static let suggestionLimit = 3

    public static func all() -> [InstalledApp] {
        if let cache { return cache }
        return refresh()
    }

    @discardableResult
    public static func refresh() -> [InstalledApp] {
        let scanned = scan()
        cache = scanned
        return scanned
    }

    public static func bundleID(for app: AppID) throws -> String {
        try resolve(name: app.rawValue)
    }

    public static func resolve(name: String) throws -> String {
        switch match(name, in: all()) {
        case .found(let app):
            return app.bundleID
        case .ambiguous(let candidates):
            throw EngineError.ambiguousApp(name: name, candidates: candidates.map(\.name))
        case .notFound:
            break
        }

        switch match(name, in: refresh()) {
        case .found(let app):
            return app.bundleID
        case .ambiguous(let candidates):
            throw EngineError.ambiguousApp(name: name, candidates: candidates.map(\.name))
        case .notFound:
            throw EngineError.appNotFound(name: name, suggestions: suggestions(for: name))
        }
    }

    public static func isBrowser(bundleID: String) -> Bool {
        browserBundleIDs().contains(bundleID)
    }

    private static var browserCache: Set<String>?

    private static func browserBundleIDs() -> Set<String> {
        if let browserCache { return browserCache }
        guard let probe = URL(string: "https://example.com") else { return [] }
        let ids = Set(
            NSWorkspace.shared.urlsForApplications(toOpen: probe)
                .compactMap { Bundle(url: $0)?.bundleIdentifier })
        browserCache = ids
        return ids
    }

    public static func displayName(bundleID: String) -> String? {
        all().first { $0.bundleID == bundleID }?.name
    }

    public static func suggestions(for name: String) -> [String] {
        let needle = normalized(name)
        guard !needle.isEmpty else { return [] }
        return all()
            .filter { normalized($0.name).contains(needle) || normalized($0.name).hasPrefix(needle) }
            .prefix(suggestionLimit)
            .map(\.name)
    }

    public enum MatchResult: Sendable, Equatable {
        case found(InstalledApp)
        case ambiguous([InstalledApp])
        case notFound
    }

    public nonisolated static func match(_ query: String, in apps: [InstalledApp]) -> MatchResult {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .notFound }
        let lowered = trimmed.lowercased()

        if let exact = apps.first(where: {
            $0.name.lowercased() == lowered || $0.fileName.lowercased() == lowered
                || $0.bundleID.lowercased() == lowered
        }) {
            return .found(exact)
        }

        let needle = normalized(trimmed)
        let normalizedMatches = apps.filter {
            normalized($0.name) == needle || normalized($0.fileName) == needle
        }
        if let single = single(normalizedMatches) { return .found(single) }
        if normalizedMatches.count > 1 { return .ambiguous(normalizedMatches) }

        let wordMatches = apps.filter { app in
            words(app.name).contains(lowered) || words(app.fileName).contains(lowered)
        }
        if let single = single(wordMatches) { return .found(single) }
        if wordMatches.count > 1 { return .ambiguous(wordMatches) }

        return .notFound
    }

    private nonisolated static func single(_ apps: [InstalledApp]) -> InstalledApp? {
        apps.count == 1 ? apps[0] : nil
    }

    private nonisolated static func normalized(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private nonisolated static func words(_ text: String) -> Set<String> {
        Set(text.lowercased().split { !($0.isLetter || $0.isNumber) }.map(String.init))
    }

    private static var searchPaths: [String] {
        [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "/System/Library/CoreServices",
            NSHomeDirectory() + "/Applications",
        ]
    }

    private static func scan() -> [InstalledApp] {
        let fileManager = FileManager.default
        var seen = Set<String>()
        var apps: [InstalledApp] = []

        for directory in searchPaths {
            for path in entries(in: directory, using: fileManager) {
                guard let app = read(path: path, using: fileManager),
                      seen.insert(app.bundleID).inserted else { continue }
                apps.append(app)
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func entries(in directory: String, using fileManager: FileManager) -> [String] {
        guard let names = try? fileManager.contentsOfDirectory(atPath: directory) else { return [] }
        return names.flatMap { name -> [String] in
            let path = directory + "/" + name
            if name.hasSuffix(".app") { return [path] }
            guard let nested = try? fileManager.contentsOfDirectory(atPath: path) else { return [] }
            return nested.filter { $0.hasSuffix(".app") }.map { path + "/" + $0 }
        }
    }

    private static func read(path: String, using fileManager: FileManager) -> InstalledApp? {
        guard let bundle = Bundle(path: path), let id = bundle.bundleIdentifier else { return nil }
        let fileName = String((path as NSString).lastPathComponent.dropLast(".app".count))
        return InstalledApp(
            name: fileManager.displayName(atPath: path), bundleID: id, fileName: fileName)
    }
}
