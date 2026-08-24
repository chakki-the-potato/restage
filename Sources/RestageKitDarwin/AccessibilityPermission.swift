import ApplicationServices
import RestageKit

public enum AccessibilityPermission {
    public static let settingsDeepLink =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    public static func isTrusted() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": false] as CFDictionary)
    }

    public static func requestIfNeeded() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    public static var onboardingMessage: String {
        L10n.string("permission.onboarding", settingsDeepLink)
    }
}
