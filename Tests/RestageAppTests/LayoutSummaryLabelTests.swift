import RestageKit
import Testing

@testable import restage

private func label(_ shape: LayoutShape, screens: Int, apps: Int = 2) -> String {
    LayoutSummaryLabel.text(
        WorkspaceSummary(apps: [], shape: shape, screenCount: screens, itemCount: apps))
}

@MainActor
@Suite(.serialized)
struct LayoutSummaryLabelTests {
    private func withKorean(_ body: () -> Void) {
        let original = L10n.language
        defer { L10n.language = original }
        L10n.language = .korean
        body()
    }

    @Test func oneScreenSaysNothingAboutScreens() {
        withKorean {
            #expect(label(.leftRight, screens: 1) == "좌우 분할")
        }
    }

    @Test func moreThanOneScreenIsSpelledOut() {
        withKorean {
            #expect(label(.leftRight, screens: 3) == "좌우 분할 · 화면 3")
        }
    }

    @Test func aSingleSlotUsesItsOwnName() {
        withKorean {
            #expect(label(.single(.leftHalf), screens: 1) == "왼쪽 절반")
        }
    }

    @Test func paneCountIsCarriedIntoTheLabel() {
        withKorean {
            #expect(label(.panes(3), screens: 1) == "3분할")
        }
    }
}
