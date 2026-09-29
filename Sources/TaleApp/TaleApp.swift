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
                    .disabled(model.isCreatingTale || model.isSearching || model.isGoingTo || model.isShowingHelp)
                Button(model.databaseURL == nil ? "Open Database…" : "Change Database…", action: model.openDatabase)
                    .keyboardShortcut("o", modifiers: .command)
                    .disabled(model.isCreatingTale || model.isSearching || model.isGoingTo || model.isShowingHelp)
            }
            CommandMenu("Entry") {
                Button("Find in Tale…", action: model.beginSearch)
                    .keyboardShortcut("f", modifiers: .command)
                    .disabled(model.activeTaleID == nil || model.isInput || model.isCreatingTale || model.isSearching || model.isGoingTo || model.isShowingHelp)
                Button("Go to…", action: model.beginGoTo)
                    .disabled(model.activeTaleID == nil || model.isInput || model.isCreatingTale || model.isSearching || model.isGoingTo || model.isShowingHelp)
                Divider()
                Button("New Note") { model.begin(.note) }.disabled(model.activeTaleID == nil || model.isCreatingTale || model.isSearching || model.isGoingTo || model.isShowingHelp)
                Button("New Todo") { model.begin(.todo) }.disabled(model.activeTaleID == nil || model.isCreatingTale || model.isSearching || model.isGoingTo || model.isShowingHelp)
                Divider()
                Button("Toggle Completion", action: model.toggleSelected)
                    .disabled(model.isShowingHelp || model.isGoingTo || model.isSearching || model.isCreatingTale || model.isInput || !model.entries.contains { $0.id == model.selectedID && $0.kind == .todo })
                Button(model.unfinishedOnly ? "Show All Entries" : "Show Unfinished Todos", action: model.toggleFilter)
                    .disabled(model.activeTaleID == nil || model.isInput || model.isCreatingTale || model.isSearching || model.isGoingTo || model.isShowingHelp)
            }
            CommandGroup(replacing: .help) {
                Button("Keyboard Shortcuts", action: model.showKeyboardHelp)
                    .disabled(model.isCreatingTale || model.isSearching || model.isGoingTo || model.isShowingHelp || model.errorMessage != nil)
            }
        }
    }
}
