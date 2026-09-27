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
                Button(model.databaseURL == nil ? "Open Database…" : "Change Database…", action: model.openDatabase)
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("Entry") {
                Button("New Note") { model.begin(.note) }.disabled(model.databaseURL == nil)
                Button("New Todo") { model.begin(.todo) }.disabled(model.databaseURL == nil)
                Divider()
                Button("Toggle Completion", action: model.toggleSelected)
                    .disabled(model.isInput || !model.entries.contains { $0.id == model.selectedID && $0.kind == .todo })
                Button(model.unfinishedOnly ? "Show All Entries" : "Show Unfinished Todos", action: model.toggleFilter)
                    .disabled(model.databaseURL == nil || model.isInput)
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts") {
                    model.errorMessage = "In navigation mode:\nN — new note\nT — new todo\n↑ / ↓ or J / K — move selection\nX — toggle todo completion\nF — show unfinished todos / all entries\n\nIn input mode:\nEnter — add entry\nEscape — keep draft and return to navigation\n\nDrafts are kept until you quit or change databases."
                }
            }
        }
    }
}
