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
        init(model: AppModel) { self.model = model }

        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let handled = MainActor.assumeIsolated {
                    guard let self, let window = self.view?.window,
                          (event.window === window || (self.model.isGoingTo && event.window === window.attachedSheet)),
                          (window.isKeyWindow || (self.model.isGoingTo && window.attachedSheet?.isKeyWindow == true)),
                          (window.attachedSheet == nil || self.model.isGoingTo), NSApp.modalWindow == nil,
                          self.model.errorMessage == nil,
                          self.model.databaseURL != nil, !self.model.isCreatingTale,
                          !self.model.isSearching else { return false }
                    let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
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
                    if modifiers == .command, event.charactersIgnoringModifiers?.lowercased() == "n" {
                        self.model.beginNewTale()
                        return true
                    }
                    guard self.model.activeTaleID != nil, !self.model.isInput,
                          modifiers.intersection([.command, .control, .option]).isEmpty else { return false }
                    switch event.keyCode {
                    case 123: self.model.moveTale(-1)
                    case 124: self.model.moveTale(1)
                    case 126: self.model.move(-1)
                    case 125: self.model.move(1)
                    default:
                        switch event.characters?.lowercased() {
                        case "g":
                            if !event.isARepeat { self.model.beginGoTo() }
                        case "/": self.model.beginSearch()
                        case "n": self.model.begin(.note)
                        case "t": self.model.begin(.todo)
                        case "j": self.model.move(1)
                        case "k": self.model.move(-1)
                        case "x": self.model.toggleSelected()
                        case "f": self.model.toggleFilter()
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
            monitor = nil
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
