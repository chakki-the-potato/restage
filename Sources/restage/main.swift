import RestageKitDarwin

if AccessibilityPermission.isTrusted() {
    print("accessibility: granted")
} else {
    print(AccessibilityPermission.onboardingMessage)
    _ = AccessibilityPermission.requestIfNeeded()
}
