import AppKit
import SwiftUI
import TaleCore

private typealias ViewState<Value> = SwiftUI.State<Value>

struct FindSheet: View {
    let model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @ViewState private var query = ""
    @ViewState private var selection: Int64?

    private var palette: TalePalette { TalePalette(colorScheme: colorScheme) }
    private var results: [Entry] { EntrySearch.results(in: model.entries, query: query) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Find in \(model.activeTale?.name ?? "this tale")")
                .font(TaleTypography.heading(size: 24))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 18)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(palette.mutedInk)
                FindField(text: $query, ink: palette.editorInk,
                          move: { selection = Navigation.movedID(in: results, selection: selection, offset: $0) },
                          submit: jump, cancel: { model.isSearching = false })
                    .frame(height: 26)
            }
            .padding(12)
            .background(palette.surface, in: RoundedRectangle(cornerRadius: 8))
            .padding(.bottom, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        if results.isEmpty {
                            Text(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Type to search" : "No results")
                                .foregroundStyle(palette.secondaryInk)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 48)
                        }
                        ForEach(results) { entry in
                            resultRow(entry)
                                .id(entry.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: selection) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
            }
            .frame(height: 300)

            HStack {
                Text("↑↓ move · enter to jump · esc to return")
                Spacer()
                Text("\(results.count) \(results.count == 1 ? "result" : "results")")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(palette.mutedInk)
            .padding(.top, 16)
        }
        .padding(28)
        .frame(width: 500)
        .foregroundStyle(palette.ink)
        .onChange(of: query) { _, _ in selection = results.first?.id }
        .onExitCommand { model.isSearching = false }
    }

    private func jump() {
        guard let selection, results.contains(where: { $0.id == selection }) else { return }
        model.jumpToSearchResult(selection)
    }

    private func resultRow(_ entry: Entry) -> some View {
        Button { model.jumpToSearchResult(entry.id) } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: entry.kind == .note ? "text.alignleft" : (entry.isCompleted ? "checkmark.square.fill" : "square"))
                    .foregroundStyle(palette.accent)
                    .frame(width: 18)
                    .padding(.top, 2)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    highlighted(entry.text)
                        .font(.system(size: 13))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(EntryTimestamp.label(for: entry.createdAt, relativeTo: .now)) · #\(entry.id)")
                        .font(.system(size: 10))
                        .foregroundStyle(palette.mutedInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(selection == entry.id ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .leading) {
                if selection == entry.id {
                    RoundedRectangle(cornerRadius: 2).fill(palette.accent).frame(width: 3).padding(.vertical, 8)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entry.kind == .note ? "Note" : (entry.isCompleted ? "Completed todo" : "Todo")): \(entry.text)")
        .accessibilityAddTraits(selection == entry.id ? .isSelected : [])
    }

    private func highlighted(_ text: String) -> Text {
        var output = Text("")
        var start = text.startIndex
        for match in EntrySearch.ranges(in: text, query: query) {
            output = output + Text(String(text[start..<match.lowerBound]))
                + Text(String(text[match])).bold().foregroundColor(palette.accent)
            start = match.upperBound
        }
        return output + Text(String(text[start...]))
    }
}

/// Keep typing focus while the field's command keys navigate results.
private struct FindField: NSViewRepresentable {
    @Binding var text: String
    let ink: NSColor
    let move: (Int) -> Void
    let submit: () -> Void
    let cancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = FocusedFindField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 16)
        field.placeholderString = "Search all entries…"
        field.cell?.usesSingleLineMode = true
        field.delegate = context.coordinator
        field.setAccessibilityLabel("Search this tale")
        field.setAccessibilityHelp("Type to search. Up and Down select results. Enter jumps to the selected result. Escape cancels.")
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        field.textColor = ink
        if field.stringValue != text { field.stringValue = text }
    }

    final class FocusedFindField: NSTextField {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.window?.makeFirstResponder(self)
            }
        }
    }

    @MainActor final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FindField
        init(parent: FindField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            // Let the input method finish composition before interpreting navigation.
            guard !textView.hasMarkedText() else { return false }
            switch selector {
            case #selector(NSResponder.moveUp(_:)): parent.move(-1)
            case #selector(NSResponder.moveDown(_:)): parent.move(1)
            case #selector(NSResponder.insertNewline(_:)): parent.submit()
            case #selector(NSResponder.cancelOperation(_:)): parent.cancel()
            default: return false
            }
            return true
        }
    }
}
