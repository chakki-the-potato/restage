import Foundation

enum LaunchContext {
    static var isInsideAppBundle: Bool {
        Bundle.main.bundleIdentifier != nil
            && Bundle.main.bundlePath.hasSuffix(".app")
    }
}
