import Testing
import CoreGraphics
@testable import RestageKit

private let vf = CGRect(x: 0, y: 70, width: 1440, height: 805)
private let primaryMaxY: CGFloat = 900

@Test func fullFillsVisibleFrameInAXCoordinates() {
    let r = SlotGeometry.frame(for: .full, in: vf, primaryMaxY: primaryMaxY)
    #expect(r == CGRect(x: 0, y: 25, width: 1440, height: 805))
}

@Test func leftHalfTakesLeftSide() {
    let r = SlotGeometry.frame(for: .leftHalf, in: vf, primaryMaxY: primaryMaxY)
    #expect(r == CGRect(x: 0, y: 25, width: 720, height: 805))
}

@Test func rightHalfStartsAtMidpoint() {
    let r = SlotGeometry.frame(for: .rightHalf, in: vf, primaryMaxY: primaryMaxY)
    #expect(r == CGRect(x: 720, y: 25, width: 720, height: 805))
}

@Test func oddWidthGivesExtraPixelToLeft() {
    let odd = CGRect(x: 0, y: 70, width: 1441, height: 805)
    let left = SlotGeometry.frame(for: .leftHalf, in: odd, primaryMaxY: primaryMaxY)
    let right = SlotGeometry.frame(for: .rightHalf, in: odd, primaryMaxY: primaryMaxY)
    #expect(left.width == 721)
    #expect(right.width == 720)
    #expect(left.maxX == right.minX)
}

@Test func topHalfIsAtSmallerAXY() {
    let r = SlotGeometry.frame(for: .topHalf, in: vf, primaryMaxY: primaryMaxY)
    #expect(r == CGRect(x: 0, y: 25, width: 1440, height: 403))
}

@Test func bottomHalfFollowsTopHalf() {
    let top = SlotGeometry.frame(for: .topHalf, in: vf, primaryMaxY: primaryMaxY)
    let bottom = SlotGeometry.frame(for: .bottomHalf, in: vf, primaryMaxY: primaryMaxY)
    #expect(bottom.minY == top.maxY)
    #expect(top.height + bottom.height == vf.height)
}

@Test func oddHeightGivesExtraPixelToTop() {
    let odd = CGRect(x: 0, y: 70, width: 1440, height: 805)
    let top = SlotGeometry.frame(for: .topHalf, in: odd, primaryMaxY: primaryMaxY)
    let bottom = SlotGeometry.frame(for: .bottomHalf, in: odd, primaryMaxY: primaryMaxY)
    #expect(top.height == 403)
    #expect(bottom.height == 402)
}

@Test func quadrantsTileTheVisibleFrame() {
    let q1 = SlotGeometry.frame(for: .q1, in: vf, primaryMaxY: primaryMaxY)
    let q2 = SlotGeometry.frame(for: .q2, in: vf, primaryMaxY: primaryMaxY)
    let q3 = SlotGeometry.frame(for: .q3, in: vf, primaryMaxY: primaryMaxY)
    let q4 = SlotGeometry.frame(for: .q4, in: vf, primaryMaxY: primaryMaxY)

    #expect(q1.minX == 0 && q1.minY == 25)
    #expect(q2.minX == 720 && q2.minY == 25)
    #expect(q3.minX == 0 && q3.minY == q1.maxY)
    #expect(q4.minX == 720 && q4.minY == q2.maxY)

    let area = q1.width * q1.height + q2.width * q2.height
             + q3.width * q3.height + q4.width * q4.height
    #expect(area == vf.width * vf.height)
}

@Test func centeredIsTwoThirdsAndCentered() {
    let r = SlotGeometry.frame(for: .centered, in: vf, primaryMaxY: primaryMaxY)
    #expect(r.width == 960)
    #expect(r.height == 537)
    #expect(r.midX == vf.midX)
}

@Test func dockOnLeftShiftsOrigin() {
    let leftDock = CGRect(x: 80, y: 0, width: 1360, height: 875)
    let r = SlotGeometry.frame(for: .leftHalf, in: leftDock, primaryMaxY: primaryMaxY)
    #expect(r.minX == 80)
    #expect(r.width == 680)
    #expect(r.minY == 25)
}

@Test func secondaryDisplayAboveOriginGetsNegativeAXY() {
    let above = CGRect(x: 0, y: 900, width: 1920, height: 1080)
    let r = SlotGeometry.frame(for: .full, in: above, primaryMaxY: primaryMaxY)
    #expect(r.minY == -1080)
}
