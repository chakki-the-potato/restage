import Testing

@testable import RestageKitDarwin

@MainActor
@Test func anAppWithEveryWindowHereCanBringUsBack() {
    #expect(HomeSpace.livesOnlyHere(here: 1, total: 1))
    #expect(HomeSpace.livesOnlyHere(here: 3, total: 3))
}

@MainActor
@Test func anAppWithWindowsElsewhereMightNotComeBackHere() {
    #expect(!HomeSpace.livesOnlyHere(here: 1, total: 2))
    #expect(!HomeSpace.livesOnlyHere(here: 0, total: 0))
}
