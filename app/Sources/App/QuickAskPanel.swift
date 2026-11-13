import AppKit

// The floating chat window. It never activates the app, so it handles every key equivalent itself:
// the main menu delivers none while another app stays active.
final class QuickAskPanel: NSPanel {
    static let autosaveName = "QuickAskPanel"
    static let defaultSize = NSSize(width: 500, height: 600)

    var onHide: (() -> Void)?
    var onNewChat: (() -> Void)?
    var onShowSettings: (() -> Void)?

    // True when a frame saved by an earlier launch was restored; otherwise the first show centers the panel.
    private(set) var restoredSavedFrame = false

    init() {
        let style: NSWindow.StyleMask = [.titled, .closable, .resizable, .nonactivatingPanel, .fullSizeContentView]
        super.init(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        titlebarAppearsTransparent = true
        appearance = NSAppearance(named: .darkAqua)
        backgroundColor = NSColor(srgbRed: 0x2B / 255, green: 0x2A / 255, blue: 0x27 / 255, alpha: 1)
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        restoredSavedFrame = setFrameUsingName(Self.autosaveName)
        setFrameAutosaveName(Self.autosaveName)
        applyLevel()
    }

    override var canBecomeKey: Bool { true }

    func applyLevel(defaults: UserDefaults = .standard) {
        let wanted = AppMode.panelLevel(isMenuBarApp: AppMode.isMenuBarApp(defaults))
        if level != wanted { level = wanted }
    }

    // Esc, including the one the composer forwards.
    override func cancelOperation(_ sender: Any?) {
        onHide?()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleShortcut(event) { return true }
        return super.performKeyEquivalent(with: event)
    }

    private func handleShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        guard let key = event.charactersIgnoringModifiers?.lowercased() else { return false }

        if flags == [.command, .shift] {
            switch key {
            case "+", "=": adjustFontSize(by: 1)
            case "z": redo()
            default: return false
            }
            return true
        }
        guard flags == .command else { return false }

        switch key {
        case "n": onNewChat?()
        case "=", "+": adjustFontSize(by: 1)
        case "-": adjustFontSize(by: -1)
        case ",": onShowSettings?()
        case "w": onHide?()
        case "c": NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
        case "x": NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
        case "v": NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
        case "a": NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
        case "z": undo()
        default: return false
        }
        return true
    }

    private func adjustFontSize(by delta: Double) {
        let defaults = UserDefaults.standard
        let range = SettingsDefault.fontSizeRange
        let current = defaults.object(forKey: SettingsKey.fontSize) as? Double ?? SettingsDefault.fontSize
        let next = min(max(current + delta, range.lowerBound), range.upperBound)
        defaults.set(next, forKey: SettingsKey.fontSize)
    }

    private func undo() {
        guard let manager = firstResponder?.undoManager, manager.canUndo else { return }
        manager.undo()
    }

    private func redo() {
        guard let manager = firstResponder?.undoManager, manager.canRedo else { return }
        manager.redo()
    }
}
