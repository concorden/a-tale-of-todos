import Foundation
import Testing
@testable import TaleCore

struct EntrySearchTests {
    @Test func matchesAccentsAndCaseWithoutLosingHighlightBoundaries() {
        let text = "👩🏽‍💻 CAFÉ and cafe\u{301}"
        let matches = EntrySearch.ranges(in: text, query: "cafe")
        #expect(matches.map { String(text[$0]) } == ["CAFÉ", "cafe\u{301}"])
    }

    @Test func spacesAndSearchSyntaxAreLiteral() {
        #expect(EntrySearch.ranges(in: "buy  milk", query: "buy milk").isEmpty)
        #expect(!EntrySearch.ranges(in: "100% [done]*_", query: "% [done]*_").isEmpty)
        #expect(EntrySearch.ranges(in: "anything", query: "").isEmpty)
        #expect(EntrySearch.ranges(in: "two words", query: "  ").isEmpty)
        #expect(EntrySearch.ranges(in: "banana", query: "xyz").isEmpty)
    }

    @Test func searchesNotesAndCompletedTodosNewestFirst() {
        let entries = [
            Entry(id: 1, kind: .note, text: "Coffee idea", createdAt: .now, isCompleted: false),
            Entry(id: 2, kind: .todo, text: "Buy coffee", createdAt: .now, isCompleted: true),
            Entry(id: 3, kind: .todo, text: "Buy tea", createdAt: .now, isCompleted: false)
        ]
        let results = EntrySearch.results(in: entries, query: "coffee")
        #expect(results.map(\.id) == [2, 1])
        #expect(Navigation.movedID(in: results, selection: 2, offset: -1) == 2)
        #expect(Navigation.movedID(in: results, selection: 2, offset: 1) == 1)
        #expect(Navigation.movedID(in: results, selection: 1, offset: 1) == 1)
    }
}
