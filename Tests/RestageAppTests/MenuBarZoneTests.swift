import AppKit
import Testing

@testable import restage

/// 노치 없는 1440x900 화면. 위 25pt를 메뉴바가, 아래 60pt를 Dock이 쓴다.
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

/// 메뉴바가 숨어 있으면 화면 위쪽 여백이 사라진다. 그때도 띠는 있어야 한다.
/// 커서를 올리는 순간을 잡지 못하면 패널이 다시 닫힌다.
@Test func aHiddenMenuBarStillLeavesABand() {
    let full = CGRect(x: 0, y: 0, width: 1440, height: 900)
    #expect(contains(700, 899, visible: full))
    #expect(!contains(700, 870, visible: full))
}

/// Dock이 아래를 차지해도 위쪽 판정에는 영향이 없어야 한다.
@Test func theDockDoesNotWidenTheBand() {
    let tallDock = CGRect(x: 0, y: 200, width: 1440, height: 675)
    #expect(contains(700, 899, visible: tallDock))
    #expect(!contains(700, 860, visible: tallDock))
}

@Test func anotherScreenSidewaysIsNotInThisBand() {
    #expect(!contains(2000, 899))
    #expect(!contains(-10, 899))
}
