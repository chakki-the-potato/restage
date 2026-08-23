import AppKit
import RestageKit

public struct InstalledApp: Sendable, Equatable {
    /// Finder에 보이는 이름. config에 쓰는 값이다.
    public let name: String
    public let bundleID: String
    /// `.app` 파일 이름에서 확장자를 뺀 것. 표시 이름과 다를 수 있다.
    public let fileName: String

    public init(name: String, bundleID: String, fileName: String) {
        self.name = name
        self.bundleID = bundleID
        self.fileName = fileName
    }
}

/// 설치된 앱을 찾아 이름을 bundle ID로 해석한다.
///
/// bundle ID 문자열은 프로젝트 전체에서 이 파일에만 존재해야 한다. RestageKit은 `AppID`라는
/// 논리 이름만 다루고, OS 고유 식별자는 이 경계에서만 나타난다.
///
/// 고정 목록을 두지 않는 이유는 이 도구를 받는 사람마다 설치된 앱이 다르기 때문이다.
/// 목록을 코드에 박으면 목록을 만든 사람의 컴퓨터에서만 쓸모가 있다.
@MainActor
public enum InstalledApps {
    private static var cache: [InstalledApp]?

    /// 표시 이름이 다른 이유로 찾기 실패했을 때 사용자에게 제안할 개수.
    private static let suggestionLimit = 3

    public static func all() -> [InstalledApp] {
        if let cache { return cache }
        return refresh()
    }

    /// 목록을 다시 읽는다. 메뉴바로 오래 떠 있는 동안 설치된 앱을 놓치지 않기 위해 필요하다.
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

        // 설치 직후일 수 있으므로 캐시를 버리고 한 번 더 본다.
        switch match(name, in: refresh()) {
        case .found(let app):
            return app.bundleID
        case .ambiguous(let candidates):
            throw EngineError.ambiguousApp(name: name, candidates: candidates.map(\.name))
        case .notFound:
            throw EngineError.appNotFound(name: name, suggestions: suggestions(for: name))
        }
    }

    /// 이 앱이 브라우저일 수 있는지. 확정이 아니라 필요조건이다.
    ///
    /// 이름 목록으로 판정하지 않는 이유는 브라우저 이름을 전부 알 수 없기 때문이다.
    /// 대신 https를 열 수 있다고 시스템에 등록되어 있는지 묻는다.
    ///
    /// 이 판정은 느슨하다. 이 컴퓨터에서 측정했더니 Chrome, Safari, Chromium과 함께
    /// iTerm과 ChatGPT도 걸렸다. 링크를 열 수 있다고 등록만 하면 걸리기 때문이다.
    /// `CFBundleDocumentTypes`의 html 뷰어 여부도 재봤으나 Safari가 빠지고 iTerm이 들어와
    /// 더 나빴다. 확실한 신호는 없다.
    ///
    /// 그래서 여기서는 걸러내기만 하고 최종 판정은 실제 탭 조회 성공 여부에 맡긴다.
    /// Notion이나 카카오톡처럼 명백히 아닌 앱은 여기서 걸러진다.
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

    // MARK: - 이름 대응

    public enum MatchResult: Sendable, Equatable {
        case found(InstalledApp)
        case ambiguous([InstalledApp])
        case notFound
    }

    /// 사용자가 적은 이름을 설치된 앱 하나에 대응시킨다.
    ///
    /// 파일 시스템을 건드리지 않는 순수 함수로 둔 이유는 이 판정이 이 파일에서 가장 틀리기 쉬운
    /// 부분이라 고정 목록으로 검증해야 하기 때문이다.
    ///
    /// 단계를 나눈 이유는 `chrome`이 `Google Chrome`을, `edge`가 `Microsoft Edge`를 가리키게
    /// 하면서도 `Claude`가 `Claude Code Notifier`로 새지 않게 하기 위해서다. 정확히 일치하는
    /// 이름이 있으면 항상 그쪽이 이긴다.
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

    // MARK: - 검색

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

    /// 표준 위치를 훑는다. 하위 폴더는 한 단계만 들어간다.
    ///
    /// Spotlight로 전부 훑지 않는 이유는 다른 앱 안에 들어 있는 도우미 앱까지 잡히기 때문이다.
    /// 이 컴퓨터에서 표준 위치는 109개, Spotlight 전체는 388개였다.
    /// 나머지는 사용자가 이름으로 부를 대상이 아니다.
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
