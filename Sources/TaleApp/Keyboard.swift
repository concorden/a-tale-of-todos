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
                          event.window === window, window.isKeyWindow,
                          window.attachedSheet == nil, NSApp.modalWindow == nil,
                          self.model.errorMessage == nil,
                          self.model.databaseURL != nil, !self.model.isInput,
                          event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return false }
                    switch event.keyCode {
                    case 126: self.model.move(-1)
                    case 125: self.model.move(1)
                    default:
                        switch event.charactersIgnoringModifiers?.lowercased() {
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
    let isInput: Bool
    let submit: () -> Void
    let escape: () -> Void
    let activate: () -> Void

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
        editor.font = NSFont.systemFont(ofSize: 15)
        editor.textColor = TalePalette(colorScheme: colorScheme).editorInk
        editor.insertionPointColor = editor.textColor
        editor.textContainerInset = NSSize(width: 0, height: 3)
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
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? PlainTextView else { return }
        editor.textColor = TalePalette(colorScheme: colorScheme).editorInk
        editor.insertionPointColor = editor.textColor
        editor.activate = activate
        editor.submit = submit
        editor.escape = escape
        if editor.string != text {
            editor.string = text
            editor.setSelectedRange(NSRange(location: (text as NSString).length, length: 0))
            editor.undoManager?.removeAllActions()
        }
        editor.isEditable = isInput
        editor.isSelectable = isInput
        if isInput && editor.window?.firstResponder !== editor {
            DispatchQueue.main.async { [weak editor] in
                guard let editor, editor.isEditable else { return }
                editor.window?.makeFirstResponder(editor)
            }
        } else if !isInput && editor.window?.firstResponder === editor {
            editor.window?.makeFirstResponder(nil)
        }
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
    var activate: (() -> Void)?

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
    override func mouseDown(with event: NSEvent) {
        if !isEditable { activate?() }
        super.mouseDown(with: event)
    }
}
