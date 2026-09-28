import AppKit
import Observation
import TaleCore
import UniformTypeIdentifiers

@MainActor @Observable
final class AppModel {
    var entries: [Entry] = []
    var selectedID: Int64?
    var kind: EntryKind = .todo
    var isInput = false
    var unfinishedOnly = false
    var noteDraft = ""
    var todoDraft = ""
    var databaseURL: URL?
    var recoveryMessage: String?
    var errorMessage: String?
    var lastSubmission: UUID?
    private var database: Database?
    private var scopedURL: URL?
    private let bookmarkKey = "databaseBookmark"
    private let pathKey = "databaseDisplayPath"

    var visibleEntries: [Entry] {
        let newestFirst = entries.reversed()
        return unfinishedOnly ? newestFirst.filter { $0.kind == .todo && !$0.isCompleted } : Array(newestFirst)
    }
    var openTodoCount: Int { entries.filter { $0.kind == .todo && !$0.isCompleted }.count }
    var draft: String {
        get { kind == .note ? noteDraft : todoDraft }
        set {
            let value = EntryText.singleLine(newValue)
            if kind == .note { noteDraft = value } else { todoDraft = value }
        }
    }
    var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && draft.count <= EntryText.limit
    }

    init() { restoreDatabase() }

    func begin(_ kind: EntryKind) {
        guard database != nil else { return }
        self.kind = kind
        if kind == .note && unfinishedOnly { toggleFilter() }
        isInput = true
    }

    func leaveInput() { isInput = false }

    func move(_ offset: Int) {
        selectedID = Navigation.movedID(in: visibleEntries, selection: selectedID, offset: offset)
    }

    func select(_ id: Int64) {
        selectedID = id
        isInput = false
    }

    func submit() {
        guard let database, canSubmit else { return }
        do {
            let entry = try SQLiteJournalPresenter.access(for: database.url) {
                try database.add(kind: kind, text: draft)
            }
            entries.append(entry)
            draft = ""
            selectedID = entry.id
            isInput = false
            lastSubmission = UUID()
        } catch { errorMessage = error.localizedDescription }
    }

    func toggleSelected() {
        guard let selectedID else { return }
        toggle(selectedID)
    }

    func toggle(_ id: Int64) {
        guard let database, let index = entries.firstIndex(where: { $0.id == id }), entries[index].kind == .todo else { return }
        let oldVisible = visibleEntries
        do {
            try SQLiteJournalPresenter.access(for: database.url) { try database.toggle(id: id) }
            let entry = entries[index]
            entries[index] = Entry(id: entry.id, kind: entry.kind, text: entry.text,
                                   createdAt: entry.createdAt, isCompleted: !entry.isCompleted)
            selectedID = Navigation.replacementID(oldEntries: oldVisible, newEntries: visibleEntries, selection: selectedID)
        } catch { errorMessage = error.localizedDescription }
    }

    func toggleFilter() {
        unfinishedOnly.toggle()
        if !visibleEntries.contains(where: { $0.id == selectedID }) { selectedID = visibleEntries.first?.id }
    }

    func createDatabase() {
        let panel = NSSavePanel()
        panel.title = "Create Database"
        panel.message = "Choose where to keep your notes and todos. Everything stays in this local file."
        panel.nameFieldStringValue = "My Tale"
        panel.allowedContentTypes = [UTType(filenameExtension: "sqlite") ?? .database]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        connect(url, create: true)
    }

    func openDatabase() {
        let panel = NSOpenPanel()
        panel.title = "Open Database"
        panel.message = "Choose a database created by A Tale of Todos."
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        connect(url, create: false)
    }

    private func restoreDatabase() {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        do {
            var stale = false
            let url = try URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope, .withoutUI],
                              relativeTo: nil, bookmarkDataIsStale: &stale)
            connect(url, create: false, restoring: true)
        } catch {
            recoveryMessage = "Your previous database couldn’t be reopened. Locate it using Open Database, or create a new one.\n\n\(UserDefaults.standard.string(forKey: pathKey) ?? "")"
        }
    }

    private func connect(_ url: URL, create: Bool, restoring: Bool = false) {
        let accessed = url.startAccessingSecurityScopedResource()
        do {
            if create { try createDatabaseFile(at: url) }
            let candidate = try SQLiteJournalPresenter.access(for: url) { try Database(url: url, create: false) }
            let loaded = try candidate.entries()
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            database = candidate
            scopedURL?.stopAccessingSecurityScopedResource()
            scopedURL = accessed ? url : nil
            databaseURL = url
            entries = loaded
            selectedID = loaded.last?.id
            unfinishedOnly = false
            isInput = false
            noteDraft = ""
            todoDraft = ""
            recoveryMessage = nil
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            UserDefaults.standard.set(url.path, forKey: pathKey)
        } catch {
            if accessed { url.stopAccessingSecurityScopedResource() }
            if restoring {
                recoveryMessage = "Your previous database couldn’t be reopened.\n\n\(url.path)\n\n\(error.localizedDescription)"
            } else { errorMessage = error.localizedDescription }
        }
    }

    private func createDatabaseFile(at url: URL) throws {
        // Initialize in the app's temporary container: a brand-new save-panel file
        // is not yet recognized as SQLite, so its journal has no related-file grant.
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sqlite")
        defer { try? FileManager.default.removeItem(at: staging) }
        do {
            let empty = try Database(url: staging, create: true)
            _ = try empty.entries()
        }
        guard !FileManager.default.fileExists(atPath: url.path) else { throw DatabaseError.fileExists }
        try FileManager.default.copyItem(at: staging, to: url)
    }
}
