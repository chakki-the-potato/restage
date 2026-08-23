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

/// 사용자가 대충 끌어다 놓으면 확신도가 떨어져야 한다. 그래야 되물을 수 있다.
@Test func roughlyPlacedWindowIsNotConfident() {
    let sloppy = CGRect(x: 40, y: 60, width: 900, height: 700)
    let match = SlotClassifier.classify(frame: sloppy, in: display)
    #expect(match != nil)
    #expect(match?.isConfident == false)
}

/// 화면을 가득 채운 창이 모든 slot에서 만점을 받으면 안 된다.
/// 교집합 비율만 쓰면 그렇게 되므로 합집합까지 반영하는지 확인한다.
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

/// 다른 디스플레이에 있는 창은 겹치지 않으므로 확신도가 0이어야 한다.
@Test func windowOnAnotherDisplayOverlapsNothing() {
    let elsewhere = CGRect(x: -2000, y: 0, width: 720, height: 805)
    let match = SlotClassifier.classify(frame: elsewhere, in: display)
    #expect(match?.overlap == 0)
    #expect(match?.isConfident == false)
}
