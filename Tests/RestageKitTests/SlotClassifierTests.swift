import CoreGraphics
import Testing
@testable import RestageKit

private let display = DisplayInfo(
    visibleFrame: CGRect(x: 0, y: 70, width: 1440, height: 805), primaryMaxY: 900)

private func frame(_ slot: Slot) -> CGRect {
    SlotGeometry.frame(for: slot, in: display.visibleFrame, primaryMaxY: display.primaryMaxY)
}

@Test func exactSlotClassifiesToItselfWithFullConfidence() {
    for slot in Slot.allCases {
        let match = SlotClassifier.classify(frame: frame(slot), in: display)
        #expect(match?.slot == slot)
        #expect(match?.overlap == 1.0)
        #expect(match?.isConfident == true)
    }
}

@Test func slightlyOffWindowStillPicksTheSameSlot() {
    let nudged = frame(.leftHalf).offsetBy(dx: 6, dy: 4)
    let match = SlotClassifier.classify(frame: nudged, in: display)
    #expect(match?.slot == .leftHalf)
    #expect(match?.isConfident == true)
}

@Test func roughlyPlacedWindowIsNotConfident() {
    let sloppy = CGRect(x: 40, y: 60, width: 900, height: 700)
    let match = SlotClassifier.classify(frame: sloppy, in: display)
    #expect(match != nil)
    #expect(match?.isConfident == false)
}

@Test func fullWindowDoesNotMatchHalfSlots() {
    let ranked = SlotClassifier.ranked(frame: frame(.full), in: display)
    #expect(ranked.first?.slot == .full)
    let leftHalf = ranked.first { $0.slot == .leftHalf }
    #expect(leftHalf != nil)
    #expect((leftHalf?.overlap ?? 1) < 0.6)
}

@Test func rankedIsSortedByOverlapDescending() {
    let ranked = SlotClassifier.ranked(frame: frame(.q1), in: display)
    #expect(ranked.count == Slot.allCases.count)
    #expect(ranked.first?.slot == .q1)
    for (previous, next) in zip(ranked, ranked.dropFirst()) {
        #expect(previous.overlap >= next.overlap)
    }
}

@Test func emptyFrameHasNoCandidates() {
    #expect(SlotClassifier.ranked(frame: .zero, in: display).isEmpty)
    #expect(SlotClassifier.classify(frame: .zero, in: display) == nil)
}

@Test func windowOnAnotherDisplayOverlapsNothing() {
    let elsewhere = CGRect(x: -2000, y: 0, width: 720, height: 805)
    let match = SlotClassifier.classify(frame: elsewhere, in: display)
    #expect(match?.overlap == 0)
    #expect(match?.isConfident == false)
}
