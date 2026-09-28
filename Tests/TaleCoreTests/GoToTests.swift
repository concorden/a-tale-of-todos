import Foundation
import Testing
@testable import TaleCore

struct GoToTests {
    // Deliberately interleaved, with a completed todo and nonconsecutive IDs.
    let entries = [
        Entry(id: 12, kind: .note, text: "Newest", createdAt: .now, isCompleted: false),
        Entry(id: 9, kind: .todo, text: "Done", createdAt: .now, isCompleted: true),
        Entry(id: 7, kind: .note, text: "Middle", createdAt: .now, isCompleted: false),
        Entry(id: 4, kind: .todo, text: "Open", createdAt: .now, isCompleted: false),
        Entry(id: 1, kind: .note, text: "Oldest", createdAt: .now, isCompleted: false)
    ]

    @Test func headAndTailUseDisplayOrder() {
        #expect(Navigation.destinationID(in: entries, selection: 7, direction: .head) == 12)
        #expect(Navigation.destinationID(in: entries, selection: 7, direction: .tail) == 1)
    }

    @Test func firstIsOldestAndLastIsNewestOfTheRequestedKind() {
        #expect(Navigation.destinationID(in: entries, selection: 7, direction: .first, kind: .todo) == 4)
        #expect(Navigation.destinationID(in: entries, selection: 7, direction: .last, kind: .todo) == 9)
        #expect(Navigation.destinationID(in: entries, selection: 7, direction: .first, kind: .note) == 1)
        #expect(Navigation.destinationID(in: entries, selection: 7, direction: .last, kind: .note) == 12)
    }

    @Test func relativeJumpsSkipOtherKindsAndExcludeCurrentEntry() {
        #expect(Navigation.destinationID(in: entries, selection: 7, direction: .previous, kind: .todo) == 9)
        #expect(Navigation.destinationID(in: entries, selection: 7, direction: .next, kind: .todo) == 4)
        #expect(Navigation.destinationID(in: entries, selection: 4, direction: .previous, kind: .todo) == 9)
        #expect(Navigation.destinationID(in: entries, selection: 9, direction: .next, kind: .todo) == 4)
        #expect(Navigation.destinationID(in: entries, selection: 7, direction: .previous, kind: .note) == 12)
        #expect(Navigation.destinationID(in: entries, selection: 7, direction: .next, kind: .note) == 1)
    }

    @Test func boundariesDoNotWrapOrReturnTheCurrentEntry() {
        #expect(Navigation.destinationID(in: entries, selection: 9, direction: .previous, kind: .todo) == nil)
        #expect(Navigation.destinationID(in: entries, selection: 4, direction: .next, kind: .todo) == nil)
        #expect(Navigation.destinationID(in: entries, selection: 12, direction: .previous, kind: .note) == nil)
        #expect(Navigation.destinationID(in: entries, selection: 1, direction: .next, kind: .note) == nil)
    }

    @Test func missingSelectionStartsAtFirstMatchingEntry() {
        #expect(Navigation.destinationID(in: entries, selection: nil, direction: .next, kind: .todo) == 9)
        #expect(Navigation.destinationID(in: entries, selection: 100, direction: .previous, kind: .note) == 12)
    }

    @Test func filteredAndEmptyViewsOnlyOfferAvailableDestinations() {
        let unfinished = entries.filter { $0.kind == .todo && !$0.isCompleted }
        #expect(Navigation.destinationID(in: unfinished, selection: 4, direction: .head) == 4)
        #expect(Navigation.destinationID(in: unfinished, selection: 4, direction: .first, kind: .note) == nil)
        #expect(Navigation.destinationID(in: unfinished, selection: 4, direction: .previous, kind: .todo) == nil)
        for direction in GoToDirection.allCases {
            #expect(Navigation.destinationID(in: [], selection: nil, direction: direction, kind: .todo) == nil)
        }
    }
}
