import Foundation

public enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case korean = "ko"
    case english = "en"

    var localizationCode: String? {
        self == .system ? nil : rawValue
    }
}

private final class BundleToken {}

public enum L10n {
    public static let defaultsKey = "preferredLanguage"

    private static let bundleName = "restage_RestageKit.bundle"

    private static var defaults: UserDefaults { AppDefaults.shared }

    private static let resources: Bundle? = {
        var roots: [URL] = []
        if let url = Bundle.main.resourceURL { roots.append(url) }
        let token = Bundle(for: BundleToken.self)
        if let url = token.resourceURL { roots.append(url) }
        roots.append(token.bundleURL.deletingLastPathComponent())
        roots.append(Bundle.main.bundleURL)
        if let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() {
            let directory = executable.deletingLastPathComponent()
            roots.append(directory)
            roots.append(directory.deletingLastPathComponent().appendingPathComponent("Resources"))
        }

        for root in roots {
            if let bundle = Bundle(url: root.appendingPathComponent(bundleName)) { return bundle }
        }
        return nil
    }()

    public static var language: AppLanguage {
        get {
            guard let raw = defaults.string(forKey: defaultsKey),
                  let language = AppLanguage(rawValue: raw)
            else { return .system }
            return language
        }
        set {
            if newValue == .system {
                defaults.removeObject(forKey: defaultsKey)
            } else {
                defaults.set(newValue.rawValue, forKey: defaultsKey)
            }
            invalidate()
        }
    }

    private struct Resolved {
        let language: AppLanguage
        let selected: Bundle?
        let english: Bundle?
    }

    private static let cacheLock = NSLock()

    nonisolated(unsafe) private static var cache: Resolved?

    private static var resolved: Resolved {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cache { return cache }
        let language = read()
        let value = Resolved(
            language: language,
            selected: lproj(language.rawValue) ?? resources,
            english: lproj(AppLanguage.english.rawValue))
        cache = value
        return value
    }

    public static func invalidate() {
        cacheLock.lock()
        cache = nil
        cacheLock.unlock()
    }

    public static func string(_ key: String) -> String {
        let current = resolved
        let english = current.english?.localizedString(forKey: key, value: key, table: nil) ?? key
        guard let selected = current.selected else { return english }
        return selected.localizedString(forKey: key, value: english, table: nil)
    }

    public static func string(_ key: String, _ arguments: any CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    public static var locale: Locale {
        Locale(identifier: effective.rawValue)
    }

    public static var effective: AppLanguage { resolved.language }

    private static func read() -> AppLanguage {
        if language != .system { return language }
        guard let resources else { return .english }
        let preferred = Bundle.preferredLocalizations(
            from: resources.localizations, forPreferences: Locale.preferredLanguages)
        return preferred.first.flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    static var resourcesForTesting: Bundle? { resources }

    private static func lproj(_ code: String) -> Bundle? {
        guard let path = resources?.path(forResource: code, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }
}
