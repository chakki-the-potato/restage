import Foundation

enum AppVersion {
    private static let key = "CFBundleShortVersionString"

    static let current: String = {
        if let override = ProcessInfo.processInfo.environment["RESTAGE_VERSION_OVERRIDE"] {
            return override
        }
        if let version = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            return version
        }
        guard let bundle = resolvedBundle(),
              let version = bundle.object(forInfoDictionaryKey: key) as? String
        else { return "dev" }
        return version
    }()

    private static func resolvedBundle() -> Bundle? {
        guard let executable = Bundle.main.executableURL?.resolvingSymlinksInPath() else {
            return nil
        }
        let url = executable
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return Bundle(url: url)
    }
}
