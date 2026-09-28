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

    private func makeDatabase() throws -> Database {
        let database = try Database(url: url, create: true)
        try database.createTale(name: "Personal")
        return database
    }

    @Test func testMixedEntriesPersistInCreationOrderAndToggleInPlace() throws {
        var database: Database? = try makeDatabase()
        let note = try database!.add(taleID: 1, kind: .note, text: "First thought")
        let todo = try database!.add(taleID: 1, kind: .todo, text: "Do a thing")
        let secondNote = try database!.add(taleID: 1, kind: .note, text: "Another thought")
        try database!.toggle(id: todo.id, taleID: 1)
        try database!.toggle(id: note.id, taleID: 1)
        database = nil

        let reopened = try Database(url: url, create: false)
        let entries = try reopened.entries()
        #expect(entries.map(\.id) == [note.id, todo.id, secondNote.id])
        #expect(entries.map(\.text) == ["First thought", "Do a thing", "Another thought"])
        #expect((entries[0].isCompleted) == false)
        #expect(entries[1].isCompleted)
        try reopened.toggle(id: todo.id, taleID: 1)
        #expect((try reopened.entries()[1].isCompleted) == false)
    }

    @Test func testUnicodeAndSQLPunctuationRoundTrip() throws {
        let database = try makeDatabase()
        let value = "It's a thought'); DROP TABLE entries; -- 👨‍👩‍👧‍👦 café 日本語\0end"
        try database.add(taleID: 1, kind: .note, text: value)
        #expect(try database.entries().first?.text == value)
    }

    @Test func testCharacterLimitUsesGraphemesAndPreservesOverlengthDraftInput() throws {
        let database = try makeDatabase()
        let atLimit = String(repeating: "👨‍👩‍👧‍👦", count: 560)
        try database.add(taleID: 1, kind: .note, text: atLimit)
        try database.add(taleID: 1, kind: .todo, text: atLimit)
        #expect(try database.entries().map { $0.text.count } == [560, 560])
        #expect(throws: (any Error).self) { try database.add(taleID: 1, kind: .note, text: atLimit + "a") }
        #expect(throws: (any Error).self) { try database.add(taleID: 1, kind: .todo, text: atLimit + "a") }
        #expect(try database.entries().count == 2)
        #expect(EntryText.singleLine(atLimit + "a").count == 561)
        #expect(try Database(url: url, create: false).entries().map { $0.text.count } == [560, 560])
    }

    @Test func testBlankEntriesAreRejectedAndPastedNewlinesFlattened() throws {
        let database = try makeDatabase()
        for blank in ["", "   ", "\t", "\r\n"] {
            #expect(throws: (any Error).self) { try database.add(taleID: 1, kind: .note, text: blank) }
        }
        try database.add(taleID: 1, kind: .note, text: "One\r\ntwo\nthree\rfour\u{2028}five\u{2029}six")
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
        var database: Database? = try makeDatabase()
        _ = try database?.add(taleID: 1, kind: .note, text: "Future data")
        database = nil
        var handle: OpaquePointer?
        #expect(sqlite3_open(url.path, &handle) == SQLITE_OK)
        #expect(sqlite3_exec(handle, "PRAGMA user_version=99", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(handle)
        #expect(throws: (any Error).self) { try Database(url: url, create: false) }
    }
    @Test func testTalesIsolateEntriesAndPersistActiveTale() throws {
        var database: Database? = try makeDatabase()
        let work = try database!.createTale(name: "Work")
        let personalEntry = try database!.add(taleID: 1, kind: .todo, text: "Personal task")
        let workEntry = try database!.add(taleID: work.id, kind: .note, text: "Work thought")
        #expect(workEntry.id > personalEntry.id)
        try database!.toggle(id: personalEntry.id, taleID: work.id)
        #expect(try database!.entries(taleID: 1).first?.isCompleted == false)
        try database!.toggle(id: personalEntry.id, taleID: 1)
        database = nil

        let reopened = try Database(url: url, create: false)
        #expect(try reopened.tales().map(\.name) == ["Personal", "Work"])
        #expect(try reopened.activeTaleID() == work.id)
        #expect(try reopened.entries(taleID: 1).map(\.text) == ["Personal task"])
        #expect(try reopened.entries(taleID: 1).first?.isCompleted == true)
        #expect(try reopened.entries(taleID: work.id) == [workEntry])
        try reopened.setActiveTale(id: 1)
        #expect(try Database(url: url, create: false).activeTaleID() == 1)
    }

    @Test func testTaleNamesAndInvalidReferences() throws {
        let database = try Database(url: url, create: true)
        #expect(try database.tales().isEmpty)
        #expect(try database.activeTaleID() == nil)
        for name in ["", "   ", "\r\n", "Invalid\0name"] {
            #expect(throws: (any Error).self) { try database.createTale(name: name) }
        }
        let tale = try database.createTale(name: "  Café 日本語 👋  ")
        #expect(tale.name == "Café 日本語 👋")
        for duplicate in ["CAFÉ 日本語 👋", "Cafe\u{301} 日本語 👋"] {
            #expect(throws: (any Error).self) { try database.createTale(name: duplicate) }
        }
        #expect(try database.tales().count == 1)
        #expect(try database.activeTaleID() == tale.id)
        #expect(throws: (any Error).self) { try database.add(taleID: 999, kind: .note, text: "Orphan") }
        #expect(throws: (any Error).self) { try database.setActiveTale(id: 999) }
        #expect(try database.activeTaleID() == tale.id)
        #expect(try database.entries().isEmpty)
        let punctuation = "It's a tale'); DROP TABLE tales; --"
        try database.createTale(name: punctuation)
        #expect(try Database(url: url, create: false).tales().last?.name == punctuation)
    }

    private func createLegacyDatabase(empty: Bool = false, corrupt: Bool = false) throws {
        var handle: OpaquePointer?
        #expect(sqlite3_open(url.path, &handle) == SQLITE_OK)
        defer { sqlite3_close(handle) }
        let sql = """
            PRAGMA application_id = 1096044356;
            PRAGMA user_version = 1;
            CREATE TABLE entries (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                kind TEXT NOT NULL,
                text TEXT NOT NULL,
                created_at REAL NOT NULL,
                completed INTEGER NOT NULL DEFAULT 0
            );
            INSERT INTO entries VALUES (3, 'note', 'Original thought', 1234567890, 0);
            INSERT INTO entries VALUES (8, 'todo', 'Original task', 1234567891, 1);
            INSERT INTO entries VALUES (42, 'note', 'Removed', 1234567892, 0);
            DELETE FROM entries WHERE id = 42;
            """
        #expect(sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK)
        if empty { #expect(sqlite3_exec(handle, "DELETE FROM entries", nil, nil, nil) == SQLITE_OK) }
        if corrupt { #expect(sqlite3_exec(handle, "UPDATE entries SET kind = 'invalid'", nil, nil, nil) == SQLITE_OK) }
    }

    @Test func testMigrationPreservesIDsDatesCompletionAndSequence() throws {
        try createLegacyDatabase()
        let database = try Database(url: url, create: false)
        #expect(try database.tales() == [Tale(id: 1, name: "Personal")])
        #expect(try database.activeTaleID() == 1)
        let entries = try database.entries(taleID: 1)
        #expect(entries.map(\.id) == [3, 8])
        #expect(entries.map(\.text) == ["Original thought", "Original task"])
        #expect(entries.map(\.createdAt) == [Date(timeIntervalSince1970: 1234567890), Date(timeIntervalSince1970: 1234567891)])
        #expect(entries.map(\.isCompleted) == [false, true])
        let work = try database.createTale(name: "Work")
        #expect(try database.add(taleID: work.id, kind: .todo, text: "New task").id == 43)
        #expect(try Database(url: url, create: false).tales().count == 2)
    }

    @Test func testEmptyLegacyDatabaseMigratesWithoutReusingIDs() throws {
        try createLegacyDatabase(empty: true)
        let database = try Database(url: url, create: false)
        #expect(try database.tales().first?.name == "Personal")
        #expect(try database.entries().isEmpty)
        #expect(try database.add(taleID: 1, kind: .note, text: "New thought").id == 43)
    }

    @Test func testInvalidLegacyDatabaseIsNotMigrated() throws {
        try createLegacyDatabase(corrupt: true)
        let original = try Data(contentsOf: url)
        #expect(throws: (any Error).self) { try Database(url: url, create: false) }
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func testFailedMigrationRollsBackSchemaAndData() throws {
        try createLegacyDatabase()
        var handle: OpaquePointer?
        #expect(sqlite3_open(url.path, &handle) == SQLITE_OK)
        // A collision after the tales table is created forces a mid-migration failure.
        #expect(sqlite3_exec(handle, "CREATE TABLE tale_state (unexpected TEXT)", nil, nil, nil) == SQLITE_OK)
        sqlite3_close(handle)
        let original = try Data(contentsOf: url)
        #expect(throws: (any Error).self) { try Database(url: url, create: false) }
        #expect(try Data(contentsOf: url) == original)
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

    @Test func testTaleNavigationWrapsInBothDirections() {
        let tales = [Tale(id: 1, name: "Personal"), Tale(id: 2, name: "Work"), Tale(id: 3, name: "Garden")]
        #expect(Navigation.movedTaleID(in: tales, selection: 1, offset: -1) == 3)
        #expect(Navigation.movedTaleID(in: tales, selection: 3, offset: 1) == 1)
        #expect(Navigation.movedTaleID(in: tales, selection: 1, offset: 1) == 2)
        #expect(Navigation.movedTaleID(in: [tales[0]], selection: 1, offset: -1) == 1)
        #expect(Navigation.movedTaleID(in: [], selection: nil, offset: 1) == nil)
    }

    @Test func testFilteredCompletionSelectsNextThenPreviousThenNothing() {
        #expect(Navigation.replacementID(oldEntries: entries, newEntries: [entries[0], entries[2]], selection: 2) == 1)
        #expect(Navigation.replacementID(oldEntries: entries, newEntries: Array(entries.prefix(2)), selection: 1) == 2)
        #expect(Navigation.replacementID(oldEntries: entries, newEntries: entries, selection: nil) == 3)
        #expect(Navigation.replacementID(oldEntries: [entries[0]], newEntries: [], selection: 3) == nil)
    }
}
