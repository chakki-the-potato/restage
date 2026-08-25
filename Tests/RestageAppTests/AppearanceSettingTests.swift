import AppKit
import Testing

@testable import restage

/// 밝기는 앱 전체가 공유하는 값이라 이 둘은 나란히 돌 수 없다.
@MainActor
@Suite(.serialized)
struct AppearanceSettingTests {
    private func matched(_ appearance: NSAppearance) -> NSAppearance.Name? {
        appearance.bestMatch(from: [.aqua, .darkAqua])
    }

    /// 창은 자기 값을 정하지 않으면 앱의 밝기를 물려받는다. 이 전제가 깨지면 밝기를
    /// 골라도 패널만 따로 논다.
    @Test func windowsInheritWhatTheAppChose() {
        let original = AppearanceSetting.current
        defer { AppearanceSetting.current = original }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.titled], backing: .buffered, defer: true)

        AppearanceSetting.current = .dark
        #expect(matched(window.effectiveAppearance) == .darkAqua)

        AppearanceSetting.current = .light
        #expect(matched(window.effectiveAppearance) == .aqua)
    }

    /// 시스템 설정을 고르면 앱은 아무것도 강제하지 않는다.
    @Test func matchingTheSystemForcesNothing() {
        let original = AppearanceSetting.current
        defer { AppearanceSetting.current = original }

        AppearanceSetting.current = .dark
        #expect(NSApplication.shared.appearance != nil)

        AppearanceSetting.current = .system
        #expect(NSApplication.shared.appearance == nil)
        #expect(UserDefaults.standard.string(forKey: AppearanceSetting.defaultsKey) == nil)
    }
}
