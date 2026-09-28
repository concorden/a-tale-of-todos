import Foundation
import SQLite3

public enum DatabaseError: LocalizedError {
    case sqlite(String), wrongFormat, unsupportedVersion, emptyEntry, tooLong, fileExists
    case emptyTaleName, duplicateTaleName

    public var errorDescription: String? {
        switch self {
        case .sqlite(let message): return "The database could not be read or saved. \(message)"
        case .wrongFormat: return "This file is not an A Tale of Todos database. Choose a database created by this app."
        case .unsupportedVersion: return "This database uses an unsupported format. Open it with the version of A Tale of Todos that created it."
        case .emptyEntry: return "Write something before adding an entry."
        case .tooLong: return "Entries can contain up to \(EntryText.limit) characters. Shorten the text and try again."
        case .emptyTaleName: return "Give your tale a name."
        case .duplicateTaleName: return "A tale with this name already exists. Choose another name."
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
            try execute("PRAGMA foreign_keys = ON")
            if create {
                try transaction {
                    try execute("PRAGMA application_id = \(Self.applicationID)")
                    try createTaleTables()
                    try execute("""
                        CREATE TABLE entries (
                            id INTEGER PRIMARY KEY AUTOINCREMENT,
                            tale_id INTEGER NOT NULL REFERENCES tales(id),
                            kind TEXT NOT NULL CHECK(kind IN ('note', 'todo')),
                            text TEXT NOT NULL CHECK(length(text) > 0),
                            created_at REAL NOT NULL,
                            completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0, 1)),
                            CHECK(kind = 'todo' OR completed = 0)
                        )
                        """)
                    try execute("CREATE INDEX entries_by_tale ON entries(tale_id, id)")
                    try execute("PRAGMA user_version = 2")
                }
            } else {
                guard try scalar("PRAGMA application_id") == Self.applicationID else { throw DatabaseError.wrongFormat }
                let version = try scalar("PRAGMA user_version")
                guard version == 1 || version == 2 else { throw DatabaseError.unsupportedVersion }
                // Validate legacy contents before touching them. Migration is atomic.
                _ = try entries()
                if version == 1 {
                    try transaction {
                        try createTaleTables()
                        try execute("INSERT INTO tales (name, name_key) VALUES ('Personal', 'personal')")
                        try execute("UPDATE tale_state SET active_tale_id = 1")
                        try execute("""
                            CREATE TABLE migrated_entries (
                                id INTEGER PRIMARY KEY AUTOINCREMENT,
                                tale_id INTEGER NOT NULL REFERENCES tales(id),
                                kind TEXT NOT NULL CHECK(kind IN ('note', 'todo')),
                                text TEXT NOT NULL CHECK(length(text) > 0),
                                created_at REAL NOT NULL,
                                completed INTEGER NOT NULL DEFAULT 0 CHECK(completed IN (0, 1)),
                                CHECK(kind = 'todo' OR completed = 0)
                            );
                            INSERT INTO migrated_entries (id, tale_id, kind, text, created_at, completed)
                                SELECT id, 1, kind, text, created_at, completed FROM entries;
                            UPDATE sqlite_sequence SET seq = MAX(seq, COALESCE((SELECT seq FROM sqlite_sequence WHERE name = 'entries'), 0))
                                WHERE name = 'migrated_entries';
                            DROP TABLE entries;
                            ALTER TABLE migrated_entries RENAME TO entries;
                            """)
                        try execute("CREATE INDEX entries_by_tale ON entries(tale_id, id)")
                        try execute("PRAGMA user_version = 2")
                        try validateTales()
                    }
                } else {
                    try validateTales()
                }
            }
        } catch {
            sqlite3_close(handle)
            handle = nil
            if create { try? FileManager.default.removeItem(at: url) }
            throw error
        }
    }

    deinit { sqlite3_close(handle) }

    public func entries(taleID: Int64? = nil) throws -> [Entry] {
        let condition = taleID == nil ? "" : " WHERE tale_id = ?"
        let statement = try prepare("SELECT id, kind, text, created_at, completed FROM entries" + condition + " ORDER BY id ASC")
        defer { sqlite3_finalize(statement) }
        if let taleID { try bind(taleID, to: statement, at: 1) }
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
    public func add(taleID: Int64, kind: EntryKind, text: String) throws -> Entry {
        let value = try EntryText.prepared(text)
        let createdAt = Date()
        let statement = try prepare("INSERT INTO entries (kind, text, created_at, tale_id) VALUES (?, ?, ?, ?)")
        defer { sqlite3_finalize(statement) }
        try bind(kind.rawValue, to: statement, at: 1)
        try bind(value, to: statement, at: 2)
        guard sqlite3_bind_double(statement, 3, createdAt.timeIntervalSince1970) == SQLITE_OK else { throw failure() }
        try bind(taleID, to: statement, at: 4)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
        return Entry(id: sqlite3_last_insert_rowid(handle), kind: kind, text: value, createdAt: createdAt, isCompleted: false)
    }

    public func toggle(id: Int64, taleID: Int64) throws {
        let statement = try prepare("UPDATE entries SET completed = 1 - completed WHERE id = ? AND tale_id = ? AND kind = 'todo'")
        defer { sqlite3_finalize(statement) }
        try bind(id, to: statement, at: 1)
        try bind(taleID, to: statement, at: 2)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }

    public func tales() throws -> [Tale] {
        let statement = try prepare("SELECT id, name, name_key FROM tales ORDER BY id ASC")
        defer { sqlite3_finalize(statement) }
        var result: [Tale] = []
        var status = sqlite3_step(statement)
        while status == SQLITE_ROW {
            guard let namePointer = sqlite3_column_text(statement, 1),
                  let keyPointer = sqlite3_column_text(statement, 2) else { throw DatabaseError.wrongFormat }
            let name = String(decoding: UnsafeBufferPointer(start: namePointer, count: Int(sqlite3_column_bytes(statement, 1))), as: UTF8.self)
            let key = String(cString: keyPointer)
            guard (try? Tale.preparedName(name)) == name, Tale.nameKey(name) == key else { throw DatabaseError.wrongFormat }
            result.append(Tale(id: sqlite3_column_int64(statement, 0), name: name))
            status = sqlite3_step(statement)
        }
        guard status == SQLITE_DONE else { throw failure() }
        return result
    }

    @discardableResult
    public func createTale(name: String) throws -> Tale {
        let name = try Tale.preparedName(name)
        return try transaction {
            let statement = try prepare("INSERT INTO tales (name, name_key) VALUES (?, ?)")
            defer { sqlite3_finalize(statement) }
            try bind(name, to: statement, at: 1)
            try bind(Tale.nameKey(name), to: statement, at: 2)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                if sqlite3_extended_errcode(handle) == 2067 { throw DatabaseError.duplicateTaleName }
                throw failure()
            }
            let tale = Tale(id: sqlite3_last_insert_rowid(handle), name: name)
            try setActiveTale(id: tale.id)
            return tale
        }
    }

    public func activeTaleID() throws -> Int64? {
        let value = try scalar("SELECT COALESCE(active_tale_id, 0) FROM tale_state WHERE id = 1")
        return value == 0 ? nil : value
    }

    public func setActiveTale(id: Int64) throws {
        let statement = try prepare("UPDATE tale_state SET active_tale_id = ? WHERE id = 1")
        defer { sqlite3_finalize(statement) }
        try bind(id, to: statement, at: 1)
        guard sqlite3_step(statement) == SQLITE_DONE else { throw failure() }
    }

    private func createTaleTables() throws {
        try execute("""
            CREATE TABLE tales (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL CHECK(length(name) > 0),
                name_key TEXT NOT NULL UNIQUE
            );
            CREATE TABLE tale_state (
                id INTEGER PRIMARY KEY CHECK(id = 1),
                active_tale_id INTEGER REFERENCES tales(id)
            );
            INSERT INTO tale_state (id) VALUES (1);
            """)
    }

    private func validateTales() throws {
        let allTales = try tales()
        let active = try activeTaleID()
        guard allTales.isEmpty ? active == nil : allTales.contains(where: { $0.id == active }) else {
            throw DatabaseError.wrongFormat
        }
        guard try scalar("SELECT COUNT(*) FROM entries LEFT JOIN tales ON entries.tale_id = tales.id WHERE tales.id IS NULL") == 0 else {
            throw DatabaseError.wrongFormat
        }
        let statement = try prepare("PRAGMA foreign_key_check")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else { throw DatabaseError.wrongFormat }
    }

    private func transaction<T>(_ work: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let result = try work()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func bind(_ value: Int64, to statement: OpaquePointer, at index: Int32) throws {
        guard sqlite3_bind_int64(statement, index, value) == SQLITE_OK else { throw failure() }
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
