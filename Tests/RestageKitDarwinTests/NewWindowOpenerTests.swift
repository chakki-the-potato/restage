import Testing

@testable import RestageKitDarwin

@MainActor
private func isNewWindow(_ key: String?, _ modifiers: Int?, enabled: Bool? = true) -> Bool {
    NewWindowOpener.isNewWindowItem(
        cmdChar: key, cmdModifiers: modifiers, isEnabled: enabled)
}

@MainActor
@Test func commandNIsTheNewWindowShortcut() {
    #expect(isNewWindow("N", 0))
    #expect(isNewWindow("n", 0))
}

@MainActor
@Test func anotherKeyOrAnExtraModifierIsSomethingElse() {
    #expect(!isNewWindow("T", 0))
    #expect(!isNewWindow("N", 1))
    #expect(!isNewWindow("N", nil))
    #expect(!isNewWindow(nil, 0))
}

@MainActor
@Test func aDisabledItemIsNotWorthPressing() {
    #expect(!isNewWindow("N", 0, enabled: false))
}

@MainActor
@Test func anItemThatSaysNothingAboutBeingEnabledIsStillPressed() {
    #expect(isNewWindow("N", 0, enabled: nil))
}
