import ApplicationServices

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
        """
        접근성 권한이 필요합니다.

        시스템 설정 > 개인정보 보호 및 보안 > 손쉬운 사용에서
        이 명령을 실행한 터미널 앱(예: iTerm)을 추가하고 켜 주세요.

        \(settingsDeepLink)
        """
    }
}
