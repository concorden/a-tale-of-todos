import SwiftUI

// Explicitly use the property wrapper on SDKs that also define a State macro.
private typealias ViewState<Value> = SwiftUI.State<Value>

private enum AppAppearance: String, CaseIterable {
    case system, light, dark

    var title: String { rawValue.capitalized }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@main
struct TaleApp: App {
    @ViewState private var model = AppModel()
    @AppStorage("appearance") private var appearance: AppAppearance = .system

    var body: some Scene {
        Window("A Tale of Todos", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 540, minHeight: 520)
                .preferredColorScheme(appearance.colorScheme)
        }
        .defaultSize(width: 780, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(after: .toolbar) {
                Menu("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppAppearance.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.inline)
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("Create Database…", action: model.createDatabase)
                    .disabled(model.isCreatingTale || model.isSearching || model.isGoingTo)
                Button(model.databaseURL == nil ? "Open Database…" : "Change Database…", action: model.openDatabase)
                    .keyboardShortcut("o", modifiers: .command)
                    .disabled(model.isCreatingTale || model.isSearching || model.isGoingTo)
            }
            CommandMenu("Entry") {
                Button("Find in Tale…", action: model.beginSearch)
                    .keyboardShortcut("f", modifiers: .command)
                    .disabled(model.activeTaleID == nil || model.isInput || model.isCreatingTale || model.isSearching || model.isGoingTo)
                Button("Go to…", action: model.beginGoTo)
                    .disabled(model.activeTaleID == nil || model.isInput || model.isCreatingTale || model.isSearching || model.isGoingTo)
                Divider()
                Button("New Note") { model.begin(.note) }.disabled(model.activeTaleID == nil || model.isCreatingTale || model.isSearching || model.isGoingTo)
                Button("New Todo") { model.begin(.todo) }.disabled(model.activeTaleID == nil || model.isCreatingTale || model.isSearching || model.isGoingTo)
                Divider()
                Button("Toggle Completion", action: model.toggleSelected)
                    .disabled(model.isGoingTo || model.isSearching || model.isCreatingTale || model.isInput || !model.entries.contains { $0.id == model.selectedID && $0.kind == .todo })
                Button(model.unfinishedOnly ? "Show All Entries" : "Show Unfinished Todos", action: model.toggleFilter)
                    .disabled(model.activeTaleID == nil || model.isInput || model.isCreatingTale || model.isSearching || model.isGoingTo)
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    model.errorMessage = "In navigation mode:\nN — new note\nT — new todo\n↑ / ↓ or J / K — move selection\n← / → — switch tales (wraps around)\nX — toggle todo completion\nF — show unfinished todos / all entries\nG — go to an entry\n/ or ⌘F — find in this tale\n\n⌘N — create a named tale\n\nIn input mode:\nEnter — add entry\nEscape — keep draft and return to navigation\n\nIn find:\n↑ / ↓ — select result\nEnter — jump to entry\nEscape — cancel\n\nIn Go to:\nH / T — head (newest) / tail (oldest)\nP / N — previous / next in display order\nF / L — first (oldest) / last (newest)\nThen N / T — note / todo\nJumps use the current view and do not wrap.\nDelete — back to directions\nEscape — cancel\n\nEach tale keeps its own drafts until you quit or change databases."
                }
                .disabled(model.isSearching || model.isGoingTo)
            }
        }
    }
}
