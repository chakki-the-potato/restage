import Foundation

public enum AppDefaults {
    public static let identifier = "com.chakki.restage"

    public static var shared: UserDefaults {
        if Bundle.main.bundleIdentifier == identifier { return .standard }
        return UserDefaults(suiteName: identifier) ?? .standard
    }
}
