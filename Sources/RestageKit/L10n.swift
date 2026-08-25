import Foundation

/// The language used on screen and in the terminal.
///
/// `system` follows what macOS chose. The others were picked by the user in the panel.
public enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case korean = "ko"
    case english = "en"

    /// The lproj name to look for in the bundle. Automatic has none; the system chooses.
    var localizationCode: String? {
        self == .system ? nil : rawValue
    }
}

/// Where translated text is read from.
///
/// `String(localized:)` isn't used because the language has to be changeable inside the app.
/// That API only sees the language fixed when the process started, so reflecting the user's
/// choice would need a restart. Here the chosen lproj bundle is opened directly, so it is immediate.
///
/// English is the base language. A key missing a translation falls back to English, and with
/// English missing too, to the key itself. A key on screen makes the gap obvious at once.
/// A marker that fixes where `Bundle.module` is found. The bundle holding this class is the
/// resource bundle's neighbour.
private final class BundleToken {}

public enum L10n {
    public static let defaultsKey = "preferredLanguage"

    private static let bundleName = "restage_RestageKit.bundle"

    /// Where the setting is stored.
    ///
    /// `UserDefaults.standard` won't do. The installer and the formula symlink `bin/restage` into
    /// the app bundle, and run through that link `Bundle.main` doesn't point at the app bundle, so
    /// there is no bundle identifier. The standard store then looks somewhere else than the app,
    /// and the terminal can't see the language chosen in the menu bar. Pin the place by name.
    private static let identifier = "com.chakki.restage"

    /// There is only one stored value, so opening it every time is fine. As a constant Swift 6
    /// treats it as shared mutable state and refuses.
    private static var defaults: UserDefaults {
        // Run from the app bundle, the standard store already looks at that place. Opening the same
        // name as a suite there makes macOS log "using your own identifier as a suite makes no sense".
        if Bundle.main.bundleIdentifier == identifier { return .standard }
        return UserDefaults(suiteName: identifier) ?? .standard
    }

    /// The translation resource bundle. nil when it can't be found, and then text falls back to keys.
    ///
    /// `Bundle.module` isn't used because it kills the process when it can't find the bundle.
    /// It did. The installer and the formula symlink `bin/restage` into the app bundle, and run
    /// through that link `Bundle.main` points at the folder holding the link, where the resources
    /// aren't. Calling restage from the terminal died on the very first string.
    ///
    /// So it is found by hand: resolve the executable's symlink and look beside it and in Resources.
    private static let resources: Bundle? = {
        var roots: [URL] = []
        if let url = Bundle.main.resourceURL { roots.append(url) }
        let token = Bundle(for: BundleToken.self)
        if let url = token.resourceURL { roots.append(url) }
        // In tests the resource bundle sits beside the .xctest, not inside it.
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
        }
    }

    public static func string(_ key: String) -> String {
        let english = Self.english?.localizedString(forKey: key, value: key, table: nil) ?? key
        guard let selected = Self.selected else { return english }
        return selected.localizedString(forKey: key, value: english, table: nil)
    }

    public static func string(_ key: String, _ arguments: any CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    /// The locale for formatting numbers and dates. Text and formatting in different languages reads wrong.
    public static var locale: Locale {
        Locale(identifier: effective.rawValue)
    }

    /// The language actually in use. Where none was chosen, the one the system chose.
    ///
    /// The screen never shows an automatic state. What the user needs to know is which language
    /// they are reading, not who chose it.
    public static var effective: AppLanguage {
        if language != .system { return language }
        guard let resources else { return .english }
        // The user's language list is passed explicitly. Without it, en comes out even when the
        // system is ko-KR: the argument-less form reads the main bundle's language list, and a
        // binary run from the terminal has an empty one, so it falls to the first language.
        let preferred = Bundle.preferredLocalizations(
            from: resources.localizations, forPreferences: Locale.preferredLanguages)
        return preferred.first.flatMap(AppLanguage.init(rawValue:)) ?? .english
    }

    /// The window that lets tests see the same bundle.
    static var resourcesForTesting: Bundle? { resources }

    private static var selected: Bundle? {
        lproj(effective.rawValue) ?? resources
    }

    private static var english: Bundle? {
        lproj(AppLanguage.english.rawValue)
    }

    private static func lproj(_ code: String) -> Bundle? {
        guard let path = resources?.path(forResource: code, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }
}
