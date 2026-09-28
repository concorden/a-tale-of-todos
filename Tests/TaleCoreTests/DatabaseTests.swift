import Foundation
import SQLite3
import Testing
@testable import TaleCore

final class DatabaseTests {
    private var directory: URL!
    private var url: URL { directory.appendingPathComponent("test.sqlite") }

    init() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: directory) }

    @Test func testMixedEntriesPersistInCreationOrderAndToggleInPlace() throws {
        var database: Database? = try Database(url: url, create: true)
        let note = try database!.add(kind: .note, text: "First thought")
        let todo = try database!.add(kind: .todo, text: "Do a thing")
        let secondNote = try database!.add(kind: .note, text: "Another thought")
        try database!.toggle(id: todo.id)
        try database!.toggle(id: note.id)
        database = nil

        let reopened = try Database(url: url, create: false)
        let entries = try reopened.entries()
        #expect(entries.map(\.id) == [note.id, todo.id, secondNote.id])
        #expect(entries.map(\.text) == ["First thought", "Do a thing", "Another thought"])
        #expect((entries[0].isCompleted) == false)
        #expect(entries[1].isCompleted)
        try reopened.toggle(id: todo.id)
        #expect((try reopened.entries()[1].isCompleted) == false)
    }

    @Test func testUnicodeAndSQLPunctuationRoundTrip() throws {
        let database = try Database(url: url, create: true)
        let value = "It's a thought'); DROP TABLE entries; -- 👨‍👩‍👧‍👦 café 日本語\0end"
        try database.add(kind: .note, text: value)
        #expect(try database.entries().first?.text == value)
    }

    @Test func testCharacterLimitUsesGraphemesAndPreservesOverlengthDraftInput() throws {
        let database = try Database(url: url, create: true)
        let atLimit = String(repeating: "👨‍👩‍👧‍👦", count: 560)
        try database.add(kind: .note, text: atLimit)
        try database.add(kind: .todo, text: atLimit)
        #expect(try database.entries().map { $0.text.count } == [560, 560])
        #expect(throws: (any Error).self) { try database.add(kind: .note, text: atLimit + "a") }
        #expect(throws: (any Error).self) { try database.add(kind: .todo, text: atLimit + "a") }
        #expect(try database.entries().count == 2)
        #expect(EntryText.singleLine(atLimit + "a").count == 561)
        #expect(try Database(url: url, create: false).entries().map { $0.text.count } == [560, 560])
    }

    @Test func testBlankEntriesAreRejectedAndPastedNewlinesFlattened() throws {
        let database = try Database(url: url, create: true)
        for blank in ["", "   ", "\t", "\r\n"] {
            #expect(throws: (any Error).self) { try database.add(kind: .note, text: blank) }
        }
        try database.add(kind: .note, text: "One\r\ntwo\nthree\rfour\u{2028}five\u{2029}six")
        #expect(try database.entries().first?.text == "One two three four five six")
    }

    @Test func testOpeningMissingFileDoesNotCreateOne() {
        #expect(throws: (any Error).self) { try Database(url: url, create: false) }
        #expect((FileManager.default.fileExists(atPath: url.path)) == false)
    }

    @Test func testCreateNeverOverwritesExistingFile() throws {
        let original = Data("keep this file".utf8)
        try original.write(to: url)
        #expect(throws: (any Error).self) { try Database(url: url, create: true) }
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func testRejectsUnrelatedSQLiteWithoutModifyingIt() throws {
        var handle: OpaquePointer?
        #expect(sqlite3_open(url.path, &handle) == SQLITE_OK)
        #expect(sqlite3_exec(handle, "CREATE TABLE unrelated (value TEXT)", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(handle)
        let original = try Data(contentsOf: url)
        #expect(throws: (any Error).self) { try Database(url: url, create: false) }
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func testRejectsUnknownSchemaVersion() throws {
        var database: Database? = try Database(url: url, create: true)
        _ = try database?.add(kind: .note, text: "Future data")
        database = nil
        var handle: OpaquePointer?
        #expect(sqlite3_open(url.path, &handle) == SQLITE_OK)
        #expect(sqlite3_exec(handle, "PRAGMA user_version=99", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(handle)
        #expect(throws: (any Error).self) { try Database(url: url, create: false) }
    }
}

struct NavigationTests {
    private let entries = (1...3).reversed().map {
        Entry(id: Int64($0), kind: .todo, text: "Todo \($0)", createdAt: .distantPast, isCompleted: false)
    }

    @Test func testNavigationStopsAtBoundariesAndSelectsNewestInitially() {
        #expect(Navigation.movedID(in: entries, selection: 3, offset: -1) == 3)
        #expect(Navigation.movedID(in: entries, selection: 1, offset: 1) == 1)
        #expect(Navigation.movedID(in: entries, selection: 2, offset: -1) == 3)
        #expect(Navigation.movedID(in: entries, selection: 3, offset: 1) == 2)
        #expect(Navigation.movedID(in: entries, selection: nil, offset: -1) == 3)
        #expect(Navigation.movedID(in: [], selection: nil, offset: 1) == nil)
    }

    @Test func testFilteredCompletionSelectsNextThenPreviousThenNothing() {
        #expect(Navigation.replacementID(oldEntries: entries, newEntries: [entries[0], entries[2]], selection: 2) == 1)
        #expect(Navigation.replacementID(oldEntries: entries, newEntries: Array(entries.prefix(2)), selection: 1) == 2)
        #expect(Navigation.replacementID(oldEntries: entries, newEntries: entries, selection: nil) == 3)
        #expect(Navigation.replacementID(oldEntries: [entries[0]], newEntries: [], selection: 3) == nil)
    }
}
