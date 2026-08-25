import Testing

@testable import RestageKitDarwin

@MainActor
@Test func aWindowOnThisDesktopIsWorthActivatingFor() {
    #expect(WindowWaiter.shouldActivate(onScreen: 1, anywhere: 1))
    #expect(WindowWaiter.shouldActivate(onScreen: 2, anywhere: 5))
}

@MainActor
@Test func anAppStillStartingIsWorthActivatingFor() {
    #expect(WindowWaiter.shouldActivate(onScreen: 0, anywhere: 0))
}

@MainActor
@Test func anAppWhoseWindowsAreOnAnotherDesktopIsNot() {
    #expect(!WindowWaiter.shouldActivate(onScreen: 0, anywhere: 1))
    #expect(!WindowWaiter.shouldActivate(onScreen: 0, anywhere: 4))
}
