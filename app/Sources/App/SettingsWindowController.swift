import AppKit
import SwiftUI

// The Settings window. An LSUIElement app opens SwiftUI's Settings scene behind other apps,
// so this controller owns a plain NSWindow and activates the app itself.
@MainActor final class SettingsWindowController {
    // Runs before the window shows; hides the floating panel so it never covers Settings.
    var onWillShow: (() -> Void)?

    private var window: NSWindow?

    var isWindowVisible: Bool { window?.isVisible == true }

    func show() {
        onWillShow?()
        let settingsWindow = window ?? makeWindow()
        NSApp.activate()
        settingsWindow.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let settingsWindow = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
        settingsWindow.styleMask = [.titled, .closable]
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.title = "Quick Ask Settings"
        settingsWindow.center()
        window = settingsWindow
        return settingsWindow
    }
}
