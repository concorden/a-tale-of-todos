import Foundation
import SQLite3

public enum DatabaseError: LocalizedError {
    case sqlite(String), wrongFormat, unsupportedVersion, emptyEntry, tooLong, fileExists

    public var errorDescription: String? {
        switch self {
        case .sqlite(let message): return "The database could not be read or saved. \(message)"
        case .wrongFormat: return "This file is not an A Tale of Todos database. Choose a database created by this app."
        case .unsupportedVersion: return "This database uses an unsupported format. Open it with the version of A Tale of Todos that created it."
        case .emptyEntry: return "Write something before adding an entry."
        case .tooLong: return "Entries can contain up to \(EntryText.limit) characters. Shorten the text and try again."
        case .fileExists: return "A file already exists at this location. Choose a new filename, or use Open Database."
        }
    }
}

public final class Database {
    private var handle: OpaquePointer?
    private static let applicationID: Int64 = 0x41544F44
    public let url: URL

    public init(url: URL, create: Bool) throws {
        self.url = url
        // Exclusive creation prevents replacing an existing database, even if a save panel approves it.
        if create {
            let descriptor = open(url.path, O_CREAT | O_EXCL | O_WRONLY, S_IRUSR | S_IWUSR)
            guard descriptor >= 0 else {
                if errno == EEXIST { throw DatabaseError.fileExists }
                throw DatabaseError.sqlite(String(cString: strerror(errno)))
            }
            close(descriptor)
        }
        do {
            let result = sqlite3_open_v2(url.path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil)
            guard result == SQLITE_OK else { throw failure() }
            sqlite3_busy_timeout(handle, 3_000)
            if create {
                try execute("BEGIN IMMEDIATE")
                do {
                    try execute("PRAGMA application_id = \(Self.applicationID)")
                    try execute("PRAGMA user_version = 1")
                    try execute("""
                        CREATE TABLE entries (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            kind TEXT NOT NULL CHECK(kind IN ('note', 'todo')),
                            text TEXT NOT NULL CHECK(length(text) > 0),
                            created_at REAL NOT NULL,
                            completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0, 1)),
                            CHECK(kind = 'todo' OR completed = 0)
                        )
                        """)
                    try execute("COMMIT")
                } catch {
                    try? execute("ROLLBACK")
                    throw error
                }
            } else {
                guard try scalar("PRAGMA application_id") == Self.applicationID else { throw DatabaseError.wrongFormat }
                guard try scalar("PRAGMA user_version") == 1 else { throw DatabaseError.unsupportedVersion }
                // Check the schema and contents before accepting a selected file.
                _ = try entries()
            }
        } catch {
            sqlite3_close(handle)
            handle = nil
            if create { try? FileManager.default.removeItem(at: url) }
            throw error
        }
    }

    deinit { sqlite3_close(handle) }

    public func entries() throws -> [Entry] {
        let statement = try prepare("SELECT id, kind, text, created_at, completed FROM entries ORDER BY id ASC")
        defer { sqlite3_finalize(statement) }
        var entries: [Entry] = []
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            guard let kindPointer = sqlite3_column_text(statement, 1),
                  let textPointer = sqlite3_column_text(statement, 2),
                  let kind = EntryKind(rawValue: String(cString: kindPointer)) else { throw DatabaseError.wrongFormat }
            let text = String(decoding: UnsafeBufferPointer(start: textPointer, count: Int(sqlite3_column_bytes(statement, 2))), as: UTF8.self)
            let completed = sqlite3_column_int(statement, 4)
            guard (try? EntryText.prepared(text)) == text,
                  EntryText.singleLine(text) == text,
                  completed == 0 || (completed == 1 && kind == .todo) else { throw DatabaseError.wrongFormat }
            entries.append(Entry(
                id: sqlite3_column_int64(statement, 0), kind: kind, text: text,
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)),
                isCompleted: completed == 1
            ))
            result = sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else { throw failure() }
        return entries
    }

    @discardableResult
    public func add(kind: EntryKind, text: String) throws -> Entry {
        let value = try EntryText.prepared(text)
        let createdAt = Date()
        let statement = try prepare("INSERT INTO entries (kind, text, created_at) VALUES (?, ?, ?)")
        defer { sqlite3_finalize(statement) }
        try bind(kind.rawValue, to: statement, at: 1)
        try bind(value, to: statement, at: 2)
        guard sqlite3_bind_double(statement, 3, createdAt.timeIntervalSince1970) == SQLITE_OK else { throw failure() }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
        return Entry(id: sqlite3_last_insert_rowid(handle), kind: kind, text: value, createdAt: createdAt, isCompleted: false)
    }

    public func toggle(id: Int64) throws {
        let statement = try prepare("UPDATE entries SET completed = 1 - completed WHERE id = ? AND kind = 'todo'")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_bind_int64(statement, 1, id) == SQLITE_OK else { throw failure() }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }

    private func failure() -> DatabaseError {
        .sqlite(handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Unable to open the file.")
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw failure() }
        return statement
    }

    private func scalar(_ sql: String) throws -> Int64 {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw failure() }
        return sqlite3_column_int64(statement, 0)
    }

    private func bind(_ text: String, to statement: OpaquePointer, at index: Int32) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let result = text.withCString { sqlite3_bind_text(statement, index, $0, Int32(text.utf8.count), transient) }
        guard result == SQLITE_OK else { throw failure() }
    }
}
