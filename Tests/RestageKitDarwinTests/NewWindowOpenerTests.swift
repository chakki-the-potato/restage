import Testing

@testable import RestageKitDarwin

@MainActor
@Test func commandNIsTheNewWindowShortcut() {
    #expect(NewWindowOpener.isNewWindowItem(cmdChar: "N", cmdModifiers: 0))
    #expect(NewWindowOpener.isNewWindowItem(cmdChar: "n", cmdModifiers: 0))
}

@MainActor
@Test func anotherKeyOrAnExtraModifierIsSomethingElse() {
    #expect(!NewWindowOpener.isNewWindowItem(cmdChar: "T", cmdModifiers: 0))
    #expect(!NewWindowOpener.isNewWindowItem(cmdChar: "N", cmdModifiers: 1))
    #expect(!NewWindowOpener.isNewWindowItem(cmdChar: "N", cmdModifiers: nil))
    #expect(!NewWindowOpener.isNewWindowItem(cmdChar: nil, cmdModifiers: 0))
}
