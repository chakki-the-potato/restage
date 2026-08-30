import CoreGraphics
import Testing

@testable import RestageKitDarwin

private let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)

private func window(_ number: Int, spaces: [Int], at origin: CGPoint = .zero) -> WindowCensus.Window {
    WindowCensus.Window(
        number: number,
        frame: CGRect(origin: origin, size: CGSize(width: 800, height: 600)),
        spaces: spaces)
}

private func classify(_ windows: [WindowCensus.Window], current: Set<Int> = [1]) -> WindowCensus.Result {
    WindowCensus.classify(windows, currentSpaces: current, displays: [screen])
}

@Test func aWindowOnTheSpaceWeAreLookingAtIsHere() {
    #expect(classify([window(10, spaces: [1])]).here == [10])
}

@Test func aWindowOnAnotherSpaceIsElsewhere() {
    let result = classify([window(10, spaces: [4634])])
    #expect(result.elsewhere == [10])
    #expect(result.here.isEmpty)
}

@Test func aWindowBelongingToNoSpaceIsNotAWindowWeCount() {
    let result = classify([window(10, spaces: [])])
    #expect(result.noSpace == [10])
    #expect(result.real == 0)
}

@Test func aWindowOffEveryDisplayIsNotOnAnotherDesktop() {
    let result = classify([window(10, spaces: [1], at: CGPoint(x: -3000, y: -3000))])
    #expect(result.offDisplay == [10])
    #expect(result.elsewhere.isEmpty)
}

@Test func aSecondMonitorSpaceCountsAsHereWhenItIsTheOneShowing() {
    let result = classify([window(10, spaces: [4538])], current: [1, 4538])
    #expect(result.here == [10])
}

@Test func theServiceWindowsThatUsedToLookLikeAnotherDesktopAreNotCounted() {
    let result = classify([
        window(1, spaces: []),
        window(2, spaces: []),
        window(3, spaces: [1]),
        window(4, spaces: [4634]),
    ])
    #expect(result.here == [3])
    #expect(result.elsewhere == [4])
    #expect(result.noSpace == [1, 2])
    #expect(result.real == 2)
}
