import AppKit
import SwiftUI
import TaleCore

struct NavigationKeyboard: NSViewRepresentable {
    let model: AppModel

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.view = view
        context.coordinator.install()
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.remove() }

    @MainActor final class Coordinator {
        let model: AppModel
        weak var view: NSView?
        var monitor: Any?
        var resignObserver: NSObjectProtocol?
        var commandHeld = false
        var pendingTaleSwitch: Task<Void, Never>?
        init(model: AppModel) { self.model = model }

        func cancelTaleSwitch() {
            pendingTaleSwitch?.cancel()
            pendingTaleSwitch = nil
            model.isSwitchingTales = false
        }

        func scheduleTaleSwitch() {
            cancelTaleSwitch()
            pendingTaleSwitch = Task { [weak self] in
                do { try await Task.sleep(for: .milliseconds(500)) }
                catch { return }
                guard !Task.isCancelled, let self else { return }
                self.pendingTaleSwitch = nil
                guard self.commandHeld, let window = self.view?.window,
                      window.isKeyWindow, window.attachedSheet == nil,
                      NSApp.modalWindow == nil else { return }
                self.model.beginTaleSwitch()
            }
        }

        func install() {
            resignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification, object: nil, queue: .main
            ) { [weak self] notification in
                let window = notification.object as? NSWindow
                MainActor.assumeIsolated {
                    guard let self, let window,
                          window === self.view?.window else { return }
                    self.cancelTaleSwitch()
                    self.commandHeld = false
                }
            }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
                let handled = MainActor.assumeIsolated {
                    guard let self else { return false }
                    let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
                    let wasCommandHeld = self.commandHeld
                    self.commandHeld = modifiers.contains(.command)
                    guard let window = self.view?.window,
                          (event.window === window || (self.model.isGoingTo && event.window === window.attachedSheet)),
                          (window.isKeyWindow || (self.model.isGoingTo && window.attachedSheet?.isKeyWindow == true)),
                          (window.attachedSheet == nil || self.model.isGoingTo), NSApp.modalWindow == nil,
                          self.model.errorMessage == nil,
                          self.model.databaseURL != nil, !self.model.isCreatingTale,
                          !self.model.isSearching, !self.model.isShowingHelp else {
                        self.cancelTaleSwitch()
                        return false
                    }
                    if event.type == .flagsChanged {
                        if modifiers != .command {
                            self.cancelTaleSwitch()
                        } else if !wasCommandHeld {
                            self.scheduleTaleSwitch()
                        }
                        return false
                    }
                    let wasChoosingTale = self.model.isSwitchingTales || self.pendingTaleSwitch != nil
                    // Any shortcut cancels the delayed popup, even before it appears.
                    self.cancelTaleSwitch()
                    if wasChoosingTale, event.keyCode == 53 { return true }
                    if self.model.isGoingTo {
                        guard modifiers.intersection([.command, .control, .option]).isEmpty else { return false }
                        // Consume the whole sequence here, including during sheet presentation.
                        // Unrecognized keys must not trigger ordinary navigation commands.
                        guard !event.isARepeat else { return true }
                        if event.keyCode == 53 { self.model.isGoingTo = false }
                        else if event.keyCode == 51 { self.model.goToBack() }
                        else if let key = event.characters?.lowercased() {
                            if self.model.goToDirection == nil {
                                if let direction = GoToDirection(rawValue: key) { self.model.chooseGoTo(direction) }
                            } else {
                                switch key {
                                case "n": self.model.finishGoTo(kind: .note)
                                case "t": self.model.finishGoTo(kind: .todo)
                                default: break
                                }
                            }
                        }
                        return true
                    }
                    if modifiers == .command {
                        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
                        if key.count == 1, let digit = key.first, ("0"..."9").contains(digit) {
                            if !event.isARepeat,
                               let index = TaleChoice.index(for: key, count: self.model.tales.count) {
                                self.model.chooseTale(self.model.tales[index].id)
                            }
                            return true
                        }
                        if key == "n" {
                            if !event.isARepeat { self.model.beginNewTale() }
                            return true
                        }
                    }
                    guard self.model.activeTaleID != nil, !self.model.isInput,
                          modifiers.intersection([.command, .control, .option]).isEmpty else { return false }
                    switch event.keyCode {
                    case 36, 76: // Return and numeric keypad Enter.
                        if !event.isARepeat { self.model.toggleSelected() }
                    case 123: self.model.moveTale(-1)
                    case 124: self.model.moveTale(1)
                    case 126: self.model.move(-1)
                    case 125: self.model.move(1)
                    default:
                        switch event.characters?.lowercased() {
                        case "?":
                            if !event.isARepeat { self.model.showKeyboardHelp() }
                        case "g":
                            if !event.isARepeat { self.model.beginGoTo() }
                        case "/": self.model.beginSearch()
                        case "n": self.model.begin(.note)
                        case "t": self.model.begin(.todo)
                        case "j": self.model.move(1)
                        case "k": self.model.move(-1)
                        case "f": self.model.toggleFilter()
                        case "c":
                            if !event.isARepeat { self.model.copySelected() }
                        default: return false
                        }
                    }
                    return true
                }
                return handled ? nil : event
            }
        }
        func remove() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
            monitor = nil
            resignObserver = nil
            cancelTaleSwitch()
        }
    }
}

/// A wrapping plain-text editor. Return submits; pasted line breaks are flattened.
struct ComposerEditor: NSViewRepresentable {
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme
    let submit: () -> Void
    let escape: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.hasHorizontalScroller = false
        let editor = PlainTextView()
        editor.isRichText = false
        editor.importsGraphics = false
        editor.drawsBackground = false
        editor.font = NSFont.systemFont(ofSize: 14)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        editor.defaultParagraphStyle = paragraph
        editor.textColor = TalePalette(colorScheme: colorScheme).editorInk
        editor.insertionPointColor = editor.textColor
        editor.textContainerInset = .zero
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.textContainer?.widthTracksTextView = true
        editor.textContainer?.lineFragmentPadding = 0
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.allowsUndo = true
        editor.delegate = context.coordinator
        editor.setAccessibilityLabel("Entry text")
        scroll.documentView = editor
        editor.typingAttributes = [.font: NSFont.systemFont(ofSize: 14), .paragraphStyle: paragraph]
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? PlainTextView else { return }
        editor.textColor = TalePalette(colorScheme: colorScheme).editorInk
        editor.insertionPointColor = editor.textColor
        editor.submit = submit
        editor.escape = escape
        if editor.string != text {
            editor.string = text
            editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            editor.undoManager?.removeAllActions()
        }
        if editor.window?.attachedSheet == nil && editor.window?.firstResponder !== editor {
            DispatchQueue.main.async { [weak editor] in
                guard let editor, editor.isEditable, editor.window?.attachedSheet == nil else { return }
                editor.window?.makeFirstResponder(editor)
            }
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView scroll: NSScrollView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0,
              let editor = scroll.documentView as? NSTextView,
              let container = editor.textContainer,
              let layout = editor.layoutManager else { return nil }
        container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        let height = max(21, ceil(layout.usedRect(for: container).height))
        return CGSize(width: width, height: height)
    }

    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerEditor
        init(parent: ComposerEditor) { self.parent = parent }
        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView else { return }
            parent.text = EntryText.singleLine(editor.string)
        }
    }
}

@MainActor final class PlainTextView: NSTextView {
    var submit: (() -> Void)?
    var escape: (() -> Void)?

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        let string = (insertString as? NSAttributedString)?.string ?? (insertString as? String) ?? ""
        super.insertText(EntryText.singleLine(string), replacementRange: replacementRange)
    }
    override func paste(_ sender: Any?) {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        insertText(string, replacementRange: selectedRange())
    }
    override func doCommand(by selector: Selector) {
        if selector == #selector(insertNewline(_:)) || selector == #selector(insertNewlineIgnoringFieldEditor(_:)) {
            submit?()
        } else if selector == #selector(cancelOperation(_:)) {
            escape?()
        } else { super.doCommand(by: selector) }
    }
}
