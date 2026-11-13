import AppKit
import SwiftUI

private extension NSColor {
    convenience init(composerHex hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
    }
}

/// NSTextView that intercepts image paste and image drops, forwards Esc to the window,
/// and draws a placeholder while empty.
final class ComposerNSTextView: NSTextView {
    var onImages: (([ImageAttachment]) -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    var placeholder = "Ask anything..." { didSet { needsDisplay = true } }

    private static let placeholderColor = NSColor(composerHex: 0x9A9893)

    private static func pasteboardHasImages(_ pasteboard: NSPasteboard) -> Bool {
        let urlOptions: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: ["public.image"],
        ]
        return pasteboard.canReadObject(forClasses: [NSURL.self], options: urlOptions)
            || pasteboard.canReadObject(forClasses: [NSImage.self], options: nil)
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocusChange?(true) }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { onFocusChange?(false) }
        return accepted
    }

    override func paste(_ sender: Any?) {
        let images = ImageAttachmentReader.fromPasteboard(.general)
        if !images.isEmpty {
            onImages?(images)
            return
        }
        pasteAsPlainText(sender)
    }

    // NSTextView maps Esc to complete:. Composing text keeps the default cancel; otherwise the window hides.
    override func cancelOperation(_ sender: Any?) {
        if hasMarkedText() {
            unmarkText()
            return
        }
        window?.cancelOperation(sender)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        if Self.pasteboardHasImages(sender.draggingPasteboard) { return .copy }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        if Self.pasteboardHasImages(sender.draggingPasteboard) {
            let images = ImageAttachmentReader.fromPasteboard(sender.draggingPasteboard)
            if !images.isEmpty {
                onImages?(images)
                return true
            }
        }
        return super.performDragOperation(sender)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !hasMarkedText() else { return }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize),
            .foregroundColor: Self.placeholderColor,
        ]
        let origin = NSPoint(x: textContainerInset.width + textContainer!.lineFragmentPadding, y: textContainerInset.height)
        NSAttributedString(string: placeholder, attributes: attributes).draw(at: origin)
    }
}

/// The composer's text box: a rounded field that grows from one line up to `maxHeight`, then scrolls.
struct ComposerTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: Double
    var focusRequest: Int
    var onSubmit: () -> Void
    var onImages: ([ImageAttachment]) -> Void
    var onFocusChange: (Bool) -> Void = { _ in }

    static let maxHeight: CGFloat = 120
    // One line is as tall as the send button, so the two line up.
    static let minHeight: CGFloat = 36
    // Distance from the field edge to its text; the model menu below uses it to line up with the text.
    static let horizontalInset: CGFloat = 14
    private static let minVerticalInset: CGFloat = 8
    private static let insets = NSSize(width: horizontalInset, height: minVerticalInset)

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder

        // sizeThatFits measures with textLayoutManager, so the view must be TextKit 2;
        // a bare init() builds a TextKit 1 view and the field would expand to fill the window.
        let textView = ComposerNSTextView(usingTextLayoutManager: true)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.drawsBackground = false
        textView.textColor = NSColor(composerHex: 0xE8E6E1)
        textView.insertionPointColor = NSColor(composerHex: 0xD97756)
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textContainerInset = Self.insets
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.string = text
        textView.onImages = { [weak coordinator = context.coordinator] images in
            coordinator?.parent.onImages(images)
        }
        textView.onFocusChange = { [weak coordinator = context.coordinator] focused in
            coordinator?.parent.onFocusChange(focused)
        }
        scrollView.documentView = textView

        context.coordinator.lastFocusRequest = focusRequest
        DispatchQueue.main.async { [weak textView] in
            guard let textView else { return }
            textView.window?.makeFirstResponder(textView)
        }
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? ComposerNSTextView else { return }
        if textView.string != text { textView.string = text }
        let font = NSFont.systemFont(ofSize: fontSize)
        if textView.font?.pointSize != font.pointSize { textView.font = font }
        if context.coordinator.lastFocusRequest != focusRequest {
            context.coordinator.lastFocusRequest = focusRequest
            textView.window?.makeFirstResponder(textView)
        }
        textView.needsDisplay = true
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSScrollView, context: Context) -> CGSize? {
        guard let textView = nsView.documentView as? ComposerNSTextView,
            let layoutManager = textView.textLayoutManager,
            let container = textView.textContainer
        else { return nil }
        let width = proposal.width ?? 300
        container.size = NSSize(width: max(width - Self.insets.width * 2, 1), height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: layoutManager.documentRange)
        let usedHeight = layoutManager.usageBoundsForTextContainer.height
        let lineHeight = (textView.font ?? NSFont.systemFont(ofSize: fontSize)).boundingRectForFont.height
        // The vertical inset centers one line in `minHeight`, and follows the font size.
        let verticalInset = max(Self.minVerticalInset, (Self.minHeight - lineHeight) / 2)
        if textView.textContainerInset.height != verticalInset {
            textView.textContainerInset = NSSize(width: Self.horizontalInset, height: verticalInset)
        }
        let contentHeight = max(usedHeight, lineHeight) + verticalInset * 2
        return CGSize(width: width, height: min(ceil(contentHeight), Self.maxHeight))
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ComposerTextView
        var lastFocusRequest = 0

        init(_ parent: ComposerTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            textView.needsDisplay = true
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true { return false }
            if textView.hasMarkedText() { return false }
            parent.onSubmit()
            return true
        }
    }
}
