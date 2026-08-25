import AppKit
import Testing

@testable import restage

private let frame = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let visible = CGRect(x: 0, y: 60, width: 1440, height: 815)
private let thickness: CGFloat = 22

private func contains(_ x: CGFloat, _ y: CGFloat, visible: CGRect = visible) -> Bool {
    MenuBarZone.contains(
        CGPoint(x: x, y: y), in: frame, visible: visible, thickness: thickness)
}

@Test func theVeryTopOfTheScreenIsTheMenuBar() {
    #expect(contains(700, 900))
    #expect(contains(700, 899))
}

@Test func justBelowTheMenuBarIsNot() {
    #expect(!contains(700, 874))
    #expect(!contains(700, 450))
}

@Test func aHiddenMenuBarStillLeavesABand() {
    let full = CGRect(x: 0, y: 0, width: 1440, height: 900)
    #expect(contains(700, 899, visible: full))
    #expect(!contains(700, 870, visible: full))
}

@Test func theDockDoesNotWidenTheBand() {
    let tallDock = CGRect(x: 0, y: 200, width: 1440, height: 675)
    #expect(contains(700, 899, visible: tallDock))
    #expect(!contains(700, 860, visible: tallDock))
}

@Test func anotherScreenSidewaysIsNotInThisBand() {
    #expect(!contains(2000, 899))
    #expect(!contains(-10, 899))
}
