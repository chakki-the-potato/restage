import AppKit
import RestageKit

public struct InstalledApp: Sendable, Equatable {
    /// The name Finder shows. This is what goes in the config.
    public let name: String
    public let bundleID: String
    /// The `.app` file name without its extension. It can differ from the display name.
    public let fileName: String

    public init(name: String, bundleID: String, fileName: String) {
        self.name = name
        self.bundleID = bundleID
        self.fileName = fileName
    }
}

/// Finds installed apps and resolves a name to a bundle ID.
///
/// Bundle ID strings must exist in this file alone. RestageKit deals only in the logical `AppID`,
/// and OS-specific identifiers appear at this boundary and nowhere else.
///
/// There is no fixed list because everyone who takes this tool has different apps installed.
/// A list baked into the code is only useful on the machine of whoever wrote it.
@MainActor
public enum InstalledApps {
    private static var cache: [InstalledApp]?

    /// How many suggestions to offer when a lookup fails because the display name differs.
    private static let suggestionLimit = 3

    public static func all() -> [InstalledApp] {
        if let cache { return cache }
        return refresh()
    }

    /// Reads the list again. Needed so apps installed while the menu bar app sits there aren't missed.
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

        // It may have been installed a moment ago, so drop the cache and look once more.
        switch match(name, in: refresh()) {
        case .found(let app):
            return app.bundleID
        case .ambiguous(let candidates):
            throw EngineError.ambiguousApp(name: name, candidates: candidates.map(\.name))
        case .notFound:
            throw EngineError.appNotFound(name: name, suggestions: suggestions(for: name))
        }
    }

    /// Whether this app could be a browser. A necessary condition, not a verdict.
    ///
    /// A list of names won't do the job because there is no knowing every browser name.
    /// Instead it asks whether the system has it registered as able to open https.
    ///
    /// The test is loose. Measured on this machine it caught iTerm and ChatGPT alongside Chrome,
    /// Safari, and Chromium, because merely registering to open links is enough.
    /// Checking `CFBundleDocumentTypes` for an html viewer was measured too, and was worse:
    /// Safari dropped out and iTerm came in. There is no reliable signal.
    ///
    /// So this only filters, and the verdict is left to whether reading tabs actually succeeds.
    /// Apps that plainly aren't browsers, like Notion or KakaoTalk, are filtered out here.
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

    // MARK: - Matching names

    public enum MatchResult: Sendable, Equatable {
        case found(InstalledApp)
        case ambiguous([InstalledApp])
        case notFound
    }

    /// Matches a name the user wrote to one installed app.
    ///
    /// It is kept a pure function that never touches the file system because this is the part of
    /// the file most likely to be wrong, and it has to be verified against a fixed list.
    ///
    /// The steps exist so that `chrome` means `Google Chrome` and `edge` means `Microsoft Edge`
    /// while `Claude` doesn't leak into `Claude Code Notifier`. An exact match always wins.
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

    // MARK: - Searching

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

    /// Walks the standard locations, descending one level into subfolders.
    ///
    /// Spotlight isn't used for a full sweep because it also catches helper apps living inside
    /// other apps. On this machine the standard locations held 109 apps and Spotlight 388.
    /// The rest are not things a user would call by name.
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
