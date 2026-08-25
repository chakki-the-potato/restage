import AppKit
import Testing

@testable import restage

@MainActor
@Suite(.serialized)
struct AppearanceSettingTests {
    private func matched(_ appearance: NSAppearance) -> NSAppearance.Name? {
        appearance.bestMatch(from: [.aqua, .darkAqua])
    }

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
