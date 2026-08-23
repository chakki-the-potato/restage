import Testing
@testable import RestageKitDarwin

@Test func settingsDeepLinkIsSet() {
    #expect(AccessibilityPermission.settingsDeepLink.hasPrefix("x-apple.systempreferences"))
}
