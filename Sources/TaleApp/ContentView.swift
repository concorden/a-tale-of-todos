import SwiftUI

private typealias ViewState<Value> = SwiftUI.State<Value>
import TaleCore

struct ContentView: View {
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var colorScheme
    @ViewState private var scrollPosition = TaleScrollPosition()
    @ViewState private var treePulse: TreePulse?

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
                            Text("Personal")
                                .font(TaleTypography.heading(size: 28))
                                .accessibilityAddTraits(.isHeader)
                                .frame(maxWidth: 690, alignment: .leading)
                                .padding(.horizontal, 28)
                                .padding(.top, 30)
                                .padding(.bottom, 32)
                            composer
                            stream
                            footer
                        }
                        tree(side: 1, width: treeWidth)
                    }
                }
            }
        }
        .background(palette.background)
        .foregroundStyle(palette.ink)
        .tint(palette.accent)
        .background(NavigationKeyboard(model: model).frame(width: 0, height: 0))
        .onChange(of: model.lastSubmission) { _, _ in
            treePulse = TreePulse()
        }
        .alert("A Tale of Todos", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private func tree(side: Int, width: CGFloat) -> some View {
        TaleTree(side: side, progress: scrollPosition.progress,
                 canScroll: scrollPosition.canScroll, hasEntries: !model.visibleEntries.isEmpty,
                 pulse: treePulse, navigate: scrollPosition.scroll)
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
                        if model.visibleEntries.isEmpty {
                            emptyStream
                        } else {
                            ForEach(model.visibleEntries) { entry in
                                EntryRow(entry: entry, now: timeline.date, selected: model.selectedID == entry.id && !model.isInput,
                                         select: { model.select(entry.id) },
                                         toggle: { model.select(entry.id); model.toggle(entry.id) })
                                    .id(entry.id)
                            }
                        }
                    }
                    .frame(maxWidth: 690)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 25)
                    .background(TaleScrollObserver(position: scrollPosition))
                }
            }
            .scrollIndicators(.hidden)
            .onAppear { proxy.scrollTo("top", anchor: .top) }
            .onChange(of: model.selectedID) { _, id in
                if let id { proxy.scrollTo(id) }
            }
            .onChange(of: model.databaseURL) { _, _ in proxy.scrollTo("top", anchor: .top) }
            .onChange(of: model.lastSubmission) { _, _ in proxy.scrollTo("top", anchor: .top) }
            .onChange(of: model.unfinishedOnly) { _, _ in
                if let id = model.selectedID { proxy.scrollTo(id) }
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
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if model.draft.isEmpty {
                    Text(model.kind == .note ? "What’s on your mind?" : "What needs doing?")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.mutedInk)
                        .padding(.top, 3)
                        .allowsHitTesting(false)
                }
                ComposerEditor(text: Binding(get: { model.draft }, set: { model.draft = $0 }),
                               isInput: model.isInput, submit: model.submit, escape: model.leaveInput,
                               activate: { model.begin(model.kind) })
                    .frame(height: 64)
            }
            HStack {
                Text(model.draft.count > EntryText.limit ? "A little shorter. Keep it to \(EntryText.limit) characters." :
                     "Enter to add · Esc to keep draft")
                    .font(.system(size: 11))
                    .foregroundStyle(model.draft.count > EntryText.limit ? Color.red : palette.secondaryInk)
                Spacer()
                if model.draft.count >= EntryText.limit - 50 {
                    Text("\(model.draft.count)/\(EntryText.limit)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(model.draft.count > EntryText.limit ? Color.red : palette.secondaryInk)
                        .accessibilityLabel("\(model.draft.count) of \(EntryText.limit) characters")
                }
            }
        }
        .opacity(model.isInput ? 1 : 0)
        .disabled(!model.isInput)
        .allowsHitTesting(model.isInput)
        .accessibilityHidden(!model.isInput)
        .overlay(alignment: .leading) {
            if !model.isInput {
                VStack(alignment: .leading, spacing: 14) {
                    Text("A note to remember. A thing to do.")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.mutedInk)
                    HStack(spacing: 20) {
                        Button(action: { model.begin(.note) }) {
                            Text(model.noteDraft.isEmpty ? "N  New note" : "N  Resume note")
                        }
                        Button(action: { model.begin(.todo) }) {
                            Text(model.todoDraft.isEmpty ? "T  New todo" : "T  Resume todo")
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(palette.secondaryInk)
                }
            }
        }
        .padding(17)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(model.isInput ? palette.accent.opacity(0.7) : palette.ink.opacity(0.09), lineWidth: 1))
        .frame(maxWidth: 690)
        .padding(.horizontal, 28)
        .padding(.top, 9)
        .padding(.bottom, 14)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if model.isInput {
                Text("INPUT · Drafts stay until you quit")
            } else {
                Text("n note · t todo · j/k move · x complete · f filter")
            }
            Spacer(minLength: 0)
            Button(action: model.toggleFilter) {
                Text(model.unfinishedOnly ? "Unfinished" : "All")
                    .foregroundStyle(model.unfinishedOnly ? palette.accent : palette.secondaryInk)
            }
            .buttonStyle(.plain)
            .disabled(model.isInput)
            .help("Toggle unfinished todos (F)")
            .accessibilityLabel("Filter: \(model.unfinishedOnly ? "Unfinished" : "All")")
        }
        .font(.system(size: 10, design: .monospaced))
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(palette.secondaryInk)
        .padding(.horizontal, 22).padding(.bottom, 16)
    }

}

private struct EntryRow: View {
    let entry: Entry
    let now: Date
    let selected: Bool
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
                Text("\(EntryTimestamp.label(for: entry.createdAt, relativeTo: now)) · #\(String(entry.id))")
                    .help(entry.createdAt.formatted(date: .complete, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundStyle(palette.mutedInk)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(selected ? palette.accent.opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .leading) {
            if selected { RoundedRectangle(cornerRadius: 2).fill(palette.accent).frame(width: 3).padding(.vertical, 13) }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: select)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(entry.kind == .todo ? (entry.isCompleted ? "Completed todo" : "Todo") : "Note"): \(entry.text)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
