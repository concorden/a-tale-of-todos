import SwiftUI

private typealias ViewState<Value> = SwiftUI.State<Value>
import TaleCore

struct ContentView: View {
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    private var scrollPosition: TaleScrollPosition { model.scrollPosition }
    @ViewState private var treePulse: TreePulse?
    @ViewState private var pinningEntryID: Int64?

    private var palette: TalePalette { TalePalette(colorScheme: colorScheme) }

    var body: some View {
        VStack(spacing: 0) {
            if model.databaseURL == nil {
                welcome
            } else {
                GeometryReader { geometry in
                    let treeWidth = min(112, max(60, geometry.size.width * 0.14))
                    HStack(spacing: 0) {
                        tree(side: 0, width: treeWidth)
                        VStack(spacing: 0) {
                            if model.activeTaleID != nil {
                                keyboardHintBar
                                    .offset(y: -geometry.safeAreaInsets.top)
                            }
                            taleHeader
                            if model.activeTaleID == nil {
                                firstTale
                            } else {
                                stream.id(model.activeTaleID)
                            }
                        }
                        tree(side: 1, width: treeWidth)
                    }
                }
            }
        }
        .background { TaleBackground() }
        .foregroundStyle(palette.ink)
        .tint(palette.accent)
        .background(NavigationKeyboard(model: model).frame(width: 0, height: 0))
        .onChange(of: model.lastSubmission) { _, _ in
            treePulse = model.lastSubmission == nil ? nil : TreePulse()
        }
        .sheet(isPresented: $model.isCreatingTale) {
            NewTaleSheet(model: model)
                .presentationBackground { TaleBackground() }
        }
        .sheet(isPresented: $model.isSearching) {
            FindSheet(model: model)
                .presentationBackground { TaleBackground() }
        }
        .sheet(isPresented: $model.isGoingTo) {
            GoToSheet(model: model)
                .presentationBackground { TaleBackground() }
        }
        .sheet(isPresented: $model.isShowingHelp) {
            KeyboardHelpSheet()
                .presentationBackground { TaleBackground() }
        }
        .alert("A Tale of Todos", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private var taleHeader: some View {
        Text(model.activeTale?.name ?? "Your tales")
            .font(TaleTypography.heading(size: 34))
            .lineLimit(1)
            .truncationMode(.tail)
            .accessibilityAddTraits(.isHeader)
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 30)
            .padding(.bottom, 48)
    }

    private var firstTale: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Every tale starts somewhere.")
                .font(TaleTypography.heading(size: 28))
            Text("Press ⌘N to name your first tale, then fill it with notes and todos.")
                .font(.system(size: 13))
                .foregroundStyle(palette.secondaryInk)
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func tree(side: Int, width: CGFloat) -> some View {
        let entries = model.visibleEntries
        return TaleTree(side: side, focusedIndex: entries.firstIndex { $0.id == model.selectedID },
                 entryCount: entries.count, isComposing: model.isInput,
                 pulse: treePulse, navigate: { index in
                     guard entries.indices.contains(index) else { return }
                     model.select(entries[index].id)
                     // Reveal the entry even if it was already selected but scrolled away.
                     model.lastGoToJump = UUID()
                 })
            .frame(width: width)
            .ignoresSafeArea(.container, edges: .vertical)
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(systemName: model.recoveryMessage == nil ? "leaf" : "externaldrive.badge.exclamationmark")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(palette.accent)
                .padding(.bottom, 22)
            Text(model.recoveryMessage == nil ? "Make room for a thought." : "Let’s find your database.")
                .font(TaleTypography.heading(size: 30))
                .padding(.bottom, 12)
            Text(model.recoveryMessage ?? "A note to remember. A thing to do.\nOne quiet place for both, saved on your Mac.")
                .font(.system(size: 13))
                .foregroundStyle(palette.secondaryInk)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .textSelection(.enabled)
                .frame(maxWidth: 420)
            HStack(spacing: 12) {
                Button("Create database…", action: model.createDatabase)
                    .buttonStyle(.borderedProminent)
                Button("Open database…", action: model.openDatabase)
                    .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .padding(.top, 27)
            Spacer()
            Label("Just this Mac. Just your file.", systemImage: "internaldrive")
                .font(.system(size: 11))
                .foregroundStyle(palette.mutedInk)
                .padding(.bottom, 26)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stream: some View {
        ScrollViewReader { proxy in
            ScrollView {
                TimelineView(.periodic(from: .now, by: 30)) { timeline in
                    LazyVStack(alignment: .leading, spacing: 5) {
                        Color.clear.frame(height: 1).id("top")
                        if model.isInput {
                            composer
                                .id("draft")
                        }
                        if model.visibleEntries.isEmpty {
                            if !model.isInput { emptyStream }
                        } else {
                            ForEach(model.visibleEntries) { entry in
                                EntryRow(entry: entry, now: timeline.date, selected: model.selectedID == entry.id && !model.isInput,
                                         isPinning: pinningEntryID == entry.id,
                                         select: { model.select(entry.id) },
                                         toggle: { model.select(entry.id); model.toggle(entry.id) })
                                    .background(TaleEntryAnchor(id: entry.id, position: scrollPosition))
                                    .id(entry.id)
                            }
                        }
                    }
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 25)
                    .background(TaleScrollObserver(position: scrollPosition,
                                                   selectedID: model.selectedID,
                                                   followScroll: model.followScroll))
                }
            }
            // `.hidden` can still reserve a macOS scrollbar gutter on overflow.
            .scrollIndicators(.never)
            .task(id: pinningEntryID) {
                guard pinningEntryID != nil else { return }
                // Let the saved row render with the draft's bottom marker before pinning it.
                do { try await Task.sleep(for: .milliseconds(30)) }
                catch { return }
                pinningEntryID = nil
            }
            .onChange(of: model.selection) { _, selection in
                if let id = selection.id, !selection.followsScroll, !model.isInput {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .onChange(of: model.isInput) { _, isInput in
                if isInput { proxy.scrollTo("top", anchor: .top) }
            }
            .onChange(of: model.databaseURL) { _, _ in proxy.scrollTo("top", anchor: .top) }
            .onChange(of: model.lastSubmission) { _, _ in proxy.scrollTo("top", anchor: .top) }
            .onChange(of: model.lastSearchJump) { _, _ in
                if let id = model.selectedID { proxy.scrollTo(id, anchor: .center) }
            }
            .onChange(of: model.lastGoToJump) { _, _ in
                if let id = model.selectedID { proxy.scrollTo(id, anchor: .center) }
            }
            .onChange(of: model.unfinishedOnly) { _, _ in
                if let id = model.selectedID, !model.isInput { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private var emptyStream: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(model.unfinishedOnly ? "Nothing left to do." : "Every tale starts somewhere.")
                .font(TaleTypography.heading(size: 28))
                .foregroundStyle(palette.ink.opacity(0.8))
            Text(model.unfinishedOnly ? "Enjoy the space. Press F to return to your full story." : "Press N to capture a thought, or T to add your first todo.")
                .font(.system(size: 13)).foregroundStyle(palette.secondaryInk)
        }
        .padding(.horizontal, 17).padding(.top, 40).padding(.bottom, 35)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var composer: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: model.kind == .todo ? "square" : "text.alignleft")
                .font(.system(size: model.kind == .todo ? 16 : 14))
                .foregroundStyle(model.kind == .todo ? palette.secondaryInk : palette.mutedInk)
                .frame(width: 20, height: 21)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                ComposerEditor(text: Binding(get: { model.draft }, set: { model.draft = $0 }),
                               submit: submitEntry, escape: model.leaveInput)
                    .frame(minHeight: 21)
                HStack(alignment: .firstTextBaseline) {
                    Text(model.draft.count > EntryText.limit
                         ? "A little shorter. Keep it to \(EntryText.limit) characters."
                         : "\(model.kind == .todo ? "New todo" : "New note") · Enter to add · Esc to keep draft")
                    Spacer(minLength: 0)
                    if model.draft.count >= EntryText.limit - 50 {
                        Text("\(model.draft.count)/\(EntryText.limit)")
                            .monospacedDigit()
                            .accessibilityLabel("\(model.draft.count) of \(EntryText.limit) characters")
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(model.draft.count > EntryText.limit ? Color.red : palette.mutedInk)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(alignment: .leading) {
            EntryFocusMarker(pinned: false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(model.kind == .todo ? "New todo" : "New note")
    }

    private func submitEntry() {
        let previousSubmission = model.lastSubmission
        model.submit()
        if model.lastSubmission != previousSubmission {
            pinningEntryID = model.selectedID
        }
    }

    private var keyboardHintBar: some View {
        HStack(spacing: 12) {
            Button("Help will be given to those who press ?", action: model.showKeyboardHelp)
                .buttonStyle(.plain)
                .help("Show keyboard shortcuts")
            Spacer(minLength: 0)
            if model.unfinishedOnly {
                Button("filter: unfinished", action: model.toggleFilter)
                    .foregroundStyle(palette.accent)
                    .buttonStyle(.plain)
                    .disabled(model.isInput)
                    .help("Clear filter (F)")
                    .accessibilityLabel("Filter: unfinished")
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(palette.secondaryInk)
        .padding(.horizontal, 22).padding(.top, 16)
    }

}

private struct NewTaleSheet: View {
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var nameFocused: Bool

    private var palette: TalePalette { TalePalette(colorScheme: colorScheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What will your next tale be about?")
                .font(TaleTypography.heading(size: 18))
                .foregroundStyle(palette.secondaryInk)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 16)

            TextField("", text: $model.newTaleName)
                .textFieldStyle(.plain)
                .font(TaleTypography.heading(size: 34))
                .foregroundStyle(palette.ink)
                .tint(palette.accent)
                .frame(minHeight: 44)
                .accessibilityLabel("Tale name")
                .accessibilityHint("Press Enter to begin your tale, or Escape to cancel.")
                .focused($nameFocused)
                .onSubmit { model.createTale() }
                .onChange(of: model.newTaleName) { _, _ in model.newTaleError = nil }

            if let message = model.newTaleError ?? (model.newTaleName.isEmpty ? nil : model.taleNameValidation) {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }

            Text("enter to begin · esc to return")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(palette.mutedInk)
                .padding(.top, 26)
        }
        .padding(40)
        .frame(width: 460)
        .onExitCommand { model.isCreatingTale = false }
        .onAppear { nameFocused = true }
    }
}

/// The same quiet margin marker for a draft (bottom) and a focused entry (top).
private struct EntryFocusMarker: View {
    let pinned: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            let travel = max(0, geometry.size.height - 6)
            ZStack(alignment: .top) {
                Rectangle()
                    .frame(width: 1, height: travel)
                    .offset(y: pinned ? 6 : 0)
                Image(systemName: "diamond.fill")
                    .font(.system(size: 6))
                    .frame(width: 6, height: 6)
                    .offset(y: pinned ? 0 : travel)
            }
            .frame(width: 6, height: geometry.size.height, alignment: .top)
        }
        .frame(width: 6)
        .foregroundStyle(TalePalette(colorScheme: colorScheme).accent)
        .padding(.vertical, 14)
        .offset(x: -2.5)
        .animation(.easeOut(duration: 0.15), value: pinned)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct EntryRow: View {
    let entry: Entry
    let now: Date
    let selected: Bool
    let isPinning: Bool
    let select: () -> Void
    let toggle: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var palette: TalePalette { TalePalette(colorScheme: colorScheme) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if entry.kind == .todo {
                Button(action: toggle) {
                    Image(systemName: entry.isCompleted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(entry.isCompleted ? palette.accent.opacity(0.65) : palette.secondaryInk)
                        .frame(width: 20, height: 21)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.isCompleted ? "Mark unfinished" : "Complete todo")
            } else {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 14))
                    .foregroundStyle(palette.mutedInk)
                    .frame(width: 20, height: 21)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(entry.text)
                    .font(.system(size: 14))
                    .lineSpacing(4)
                    .strikethrough(entry.isCompleted)
                    .foregroundStyle(entry.isCompleted ? palette.secondaryInk : palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("No. \(String(entry.id))")
                        .font(TaleTypography.heading(size: 13))
                    Text("·")
                        .accessibilityHidden(true)
                    Text(EntryTimestamp.label(for: entry.createdAt, relativeTo: now))
                }
                .help(entry.createdAt.formatted(date: .complete, time: .shortened))
                .font(.system(size: 10))
                .foregroundStyle(palette.mutedInk)
                .accessibilityElement(children: .combine)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .overlay(alignment: .leading) {
            if selected {
                EntryFocusMarker(pinned: !isPinning)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(entry.kind == .todo ? (entry.isCompleted ? "Completed todo" : "Todo") : "Note"): \(entry.text)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
