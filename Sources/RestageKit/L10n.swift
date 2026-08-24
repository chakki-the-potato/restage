import Foundation

/// 화면과 터미널에 쓰는 언어.
///
/// `system`은 macOS가 고른 언어를 따른다. 나머지는 사용자가 패널에서 직접 고른 것이다.
public enum AppLanguage: String, CaseIterable, Sendable {
    case system
    case korean = "ko"
    case english = "en"

    /// 번들에서 찾을 lproj 이름. 자동은 시스템이 고르므로 없다.
    var localizationCode: String? {
        self == .system ? nil : rawValue
    }
}

/// 번역 문구를 읽는 곳.
///
/// `String(localized:)`를 쓰지 않는 이유는 언어를 앱 안에서 바꿀 수 있어야 하기 때문이다.
/// 그 API는 프로세스가 시작할 때 정해진 언어만 보므로 사용자가 고른 언어를 반영하려면
/// 재시작해야 한다. 여기서는 고른 언어의 lproj 번들을 직접 열어 읽으므로 즉시 바뀐다.
///
/// 기준 언어는 영어다. 번역이 빠진 키는 영어로, 영어까지 없으면 키 자체로 떨어진다.
/// 키가 화면에 보이면 빠진 번역을 바로 알아볼 수 있다.
public enum L10n {
    public static let defaultsKey = "preferredLanguage"

    public static var language: AppLanguage {
        get {
            guard let raw = UserDefaults.standard.string(forKey: defaultsKey),
                  let language = AppLanguage(rawValue: raw)
            else { return .system }
            return language
        }
        set {
            if newValue == .system {
                UserDefaults.standard.removeObject(forKey: defaultsKey)
            } else {
                UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
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

    /// 숫자와 날짜 서식에 쓸 로케일. 문구와 서식이 다른 언어를 따르면 어색하다.
    public static var locale: Locale {
        guard let code = language.localizationCode else { return .current }
        return Locale(identifier: code)
    }

    private static var selected: Bundle? {
        guard let code = language.localizationCode else { return .module }
        return lproj(code) ?? .module
    }

    private static var english: Bundle? {
        lproj(AppLanguage.english.rawValue)
    }

    private static func lproj(_ code: String) -> Bundle? {
        guard let path = Bundle.module.path(forResource: code, ofType: "lproj") else { return nil }
        return Bundle(path: path)
    }
}
