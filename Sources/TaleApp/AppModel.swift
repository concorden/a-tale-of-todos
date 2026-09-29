import AppKit
import Observation
import TaleCore
import UniformTypeIdentifiers

@MainActor @Observable
final class AppModel {
    var tales: [Tale] = []
    var activeTaleID: Int64?
    var scrollPosition = TaleScrollPosition()
    var isCreatingTale = false
    var isSearching = false
    var isGoingTo = false
    var isShowingHelp = false
    var isSwitchingTales = false
    var goToDirection: GoToDirection?
    var goToMessage: String?
    var lastGoToJump: UUID?
    var lastSearchJump: UUID?
    var newTaleName = ""
    var newTaleError: String?
    private var sessions: [Int64: TaleSession] = [:]

    @MainActor private struct TaleSession {
        var selectedID: Int64?
        var kind: EntryKind = .todo
        var unfinishedOnly = false
        var noteDraft = ""
        var todoDraft = ""
        var scrollPosition = TaleScrollPosition()
    }

    var activeTale: Tale? { tales.first { $0.id == activeTaleID } }
    var taleNameValidation: String? {
        guard let name = try? Tale.preparedName(newTaleName) else { return "Give your tale a name." }
        return tales.contains { Tale.nameKey($0.name) == Tale.nameKey(name) }
            ? "A tale with this name already exists." : nil
    }

    var entries: [Entry] = []
    struct EntrySelection: Equatable {
        var id: Int64?
        var followsScroll = false
    }

    var selection = EntrySelection()
    var selectedID: Int64? {
        get { selection.id }
        set { selection = EntrySelection(id: newValue) }
    }
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

    func showKeyboardHelp() {
        guard !isCreatingTale, !isSearching, !isGoingTo, errorMessage == nil else { return }
        isShowingHelp = true
    }

    func begin(_ kind: EntryKind) {
        guard activeTaleID != nil, !isCreatingTale, !isSearching, !isGoingTo, !isShowingHelp else { return }
        self.kind = kind
        if kind == .note && unfinishedOnly { toggleFilter() }
        isInput = true
    }

    func leaveInput() { isInput = false }

    func beginSearch() {
        guard activeTaleID != nil, !isInput, !isCreatingTale, !isGoingTo, !isShowingHelp, errorMessage == nil else { return }
        isSearching = true
    }

    func beginGoTo() {
        guard activeTaleID != nil, !isInput, !isCreatingTale, !isSearching, !isShowingHelp, errorMessage == nil else { return }
        goToDirection = nil
        goToMessage = nil
        isGoingTo = true
    }

    func chooseGoTo(_ direction: GoToDirection) {
        guard isGoingTo else { return }
        goToDirection = direction
        goToMessage = nil
        if !direction.needsKind { finishGoTo() }
    }

    func finishGoTo(kind: EntryKind? = nil) {
        guard isGoingTo, let direction = goToDirection else { return }
        guard let id = Navigation.destinationID(in: visibleEntries, selection: selectedID,
                                                direction: direction, kind: kind) else {
            goToMessage = kind.map { "No \(direction.title.lowercased()) \($0.rawValue) in this view." }
                ?? "No entries in this view."
            if !direction.needsKind { goToDirection = nil }
            return
        }
        select(id)
        isGoingTo = false
        // Repeating a jump also reveals a selected entry scrolled out of view.
        lastGoToJump = UUID()
    }

    func goToBack() {
        goToDirection = nil
        goToMessage = nil
    }

    func jumpToSearchResult(_ id: Int64) {
        guard let entry = entries.first(where: { $0.id == id }) else { return }
        if unfinishedOnly && (entry.kind != .todo || entry.isCompleted) { unfinishedOnly = false }
        select(id)
        isSearching = false
        // Also scroll when the result was already selected but is outside the viewport.
        lastSearchJump = UUID()
    }

    func move(_ offset: Int) {
        selectedID = Navigation.movedID(in: visibleEntries, selection: selectedID, offset: offset)
    }

    func select(_ id: Int64) {
        selectedID = id
        isInput = false
    }

    func followScroll(_ id: Int64) {
        guard !isInput, !isCreatingTale, !isSearching, !isGoingTo, !isShowingHelp, !isSwitchingTales, errorMessage == nil,
              id != selectedID, visibleEntries.contains(where: { $0.id == id }) else { return }
        selection = EntrySelection(id: id, followsScroll: true)
    }

    func submit() {
        guard let database, let activeTaleID, canSubmit, !isCreatingTale else { return }
        do {
            let entry = try SQLiteJournalPresenter.access(for: database.url) {
                try database.add(taleID: activeTaleID, kind: kind, text: draft)
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

    func copySelected() {
        guard !isInput, let entry = visibleEntries.first(where: { $0.id == selectedID }) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
    }

    func toggle(_ id: Int64) {
        guard let database, let activeTaleID, let index = entries.firstIndex(where: { $0.id == id }), entries[index].kind == .todo else { return }
        let oldVisible = visibleEntries
        do {
            try SQLiteJournalPresenter.access(for: database.url) { try database.toggle(id: id, taleID: activeTaleID) }
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

    func beginNewTale() {
        guard database != nil, !isCreatingTale, !isSearching, !isGoingTo, !isShowingHelp else { return }
        isSwitchingTales = false
        newTaleName = ""
        newTaleError = nil
        isCreatingTale = true
    }

    func createTale() {
        guard let database, isCreatingTale, taleNameValidation == nil else { return }
        do {
            let tale = try SQLiteJournalPresenter.access(for: database.url) {
                try database.createTale(name: newTaleName)
            }
            saveSession()
            tales.append(tale)
            activate(tale.id, entries: [])
            isCreatingTale = false
        } catch { newTaleError = error.localizedDescription }
    }

    func moveTale(_ offset: Int) {
        guard !isInput, !isCreatingTale,
              let id = Navigation.movedTaleID(in: tales, selection: activeTaleID, offset: offset) else { return }
        switchTale(id)
    }

    func beginTaleSwitch() {
        guard database != nil, !isCreatingTale, !isSearching, !isGoingTo,
              !isShowingHelp, errorMessage == nil else { return }
        isSwitchingTales = true
    }

    func chooseTale(_ id: Int64) {
        isSwitchingTales = false
        switchTale(id)
    }

    private func switchTale(_ id: Int64) {
        guard let database, id != activeTaleID, tales.contains(where: { $0.id == id }), !isCreatingTale else { return }
        do {
            let loaded = try database.entries(taleID: id)
            try SQLiteJournalPresenter.access(for: database.url) { try database.setActiveTale(id: id) }
            saveSession()
            activate(id, entries: loaded)
        } catch { errorMessage = error.localizedDescription }
    }

    private func saveSession() {
        guard let activeTaleID else { return }
        scrollPosition.saveOffset()
        sessions[activeTaleID] = TaleSession(selectedID: selectedID, kind: kind, unfinishedOnly: unfinishedOnly,
                                             noteDraft: noteDraft, todoDraft: todoDraft, scrollPosition: scrollPosition)
    }

    private func activate(_ id: Int64?, entries loaded: [Entry]) {
        let session = id.flatMap { sessions[$0] } ?? TaleSession(selectedID: loaded.last?.id)
        activeTaleID = id
        entries = loaded
        selectedID = session.selectedID
        kind = session.kind
        unfinishedOnly = session.unfinishedOnly
        noteDraft = session.noteDraft
        todoDraft = session.todoDraft
        scrollPosition = session.scrollPosition
        isInput = false
        lastSubmission = nil
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
            let loadedTales = try candidate.tales()
            let activeID = try candidate.activeTaleID()
            let loaded = try activeID.map { try candidate.entries(taleID: $0) } ?? []
            let bookmark = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            database = candidate
            scopedURL?.stopAccessingSecurityScopedResource()
            scopedURL = accessed ? url : nil
            databaseURL = url
            sessions = [:]
            tales = loadedTales
            activate(activeID, entries: loaded)
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
