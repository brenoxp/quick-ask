import KeyboardShortcuts
import SwiftUI

// Menu bar app with no Dock icon; the chat lives in the panel AppDelegate owns.
@main
struct QuickAskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Quick Ask", systemImage: "bubble.left.and.text.bubble.right") {
            Button("Show Quick Ask") { appDelegate.panelController?.show() }
                .globalKeyboardShortcut(.toggleQuickAsk)
            Button("New Chat") { appDelegate.store?.newChat() }
            Divider()
            Button("Settings…") { appDelegate.settingsWindowController?.show() }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}
