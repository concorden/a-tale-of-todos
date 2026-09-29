import CoreGraphics
import Testing
@testable import TaleCore

struct ScrollFocusTests {
    let viewport = CGRect(x: 0, y: 200, width: 400, height: 400)
    let rows = Dictionary(uniqueKeysWithValues: (0..<10).map {
        (Int64($0), CGRect(x: 0, y: $0 * 80, width: 400, height: 75))
    })

    @Test func retainsFocusInsideTheComfortBand() {
        #expect(Navigation.focusFollowingScroll(in: rows, selection: 4, viewport: viewport) == 4)
        #expect(Navigation.focusFollowingScroll(in: rows, selection: 5, viewport: viewport) == 5)
    }

    @Test func followsInBothDirectionsWithContextOnEitherSide() {
        #expect(Navigation.focusFollowingScroll(in: rows, selection: 2, viewport: viewport) == 3)
        #expect(Navigation.focusFollowingScroll(in: rows, selection: 7, viewport: viewport) == 6)
    }

    @Test func missingOrUnrealizedSelectionUsesTheCenter() {
        #expect(Navigation.focusFollowingScroll(in: rows, selection: nil, viewport: viewport) == 5)
        #expect(Navigation.focusFollowingScroll(in: rows, selection: 99, viewport: viewport) == 5)
    }

    @Test func keepsATallEntryWhileReadingItsMiddle() {
        let tallRows: [Int64: CGRect] = [
            1: CGRect(x: 0, y: 0, width: 400, height: 900),
            2: CGRect(x: 0, y: 910, width: 400, height: 80)
        ]
        let top = CGRect(x: 0, y: 0, width: 400, height: 300)
        #expect(Navigation.focusFollowingScroll(in: tallRows, selection: 1, viewport: top) == 1)
    }

    @Test func emptyAndOffscreenRowsDoNotAcquireFocus() {
        #expect(Navigation.focusFollowingScroll(in: [:], selection: nil, viewport: viewport) == nil)
        #expect(Navigation.focusFollowingScroll(in: rows, selection: nil, viewport: .zero) == nil)
        let beyond = CGRect(x: 0, y: 1000, width: 400, height: 400)
        #expect(Navigation.focusFollowingScroll(in: rows, selection: nil, viewport: beyond) == nil)
    }

    @Test func shortListsAndSingleEntriesRemainSelectable() {
        let one: [Int64: CGRect] = [1: CGRect(x: 0, y: 0, width: 400, height: 70)]
        let fullView = CGRect(x: 0, y: 0, width: 400, height: 500)
        #expect(Navigation.focusFollowingScroll(in: one, selection: 1, viewport: fullView) == 1)
    }
}
