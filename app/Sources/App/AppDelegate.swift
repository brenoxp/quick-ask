import AppKit
import KeyboardShortcuts

// Owns the app's single chat store, panel and Settings window, and wires the global hotkey.
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var store: ChatStore?
    private(set) var uiState: PanelUIState?
    private(set) var panelController: PanelController?
    private(set) var settingsWindowController: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = ChatStore.live()
        let uiState = PanelUIState()
        let settings = SettingsWindowController()
        let panel = PanelController(store: store, uiState: uiState) { [weak settings] in settings?.show() }
        settings.onWillShow = { [weak panel] in panel?.hide() }

        self.store = store
        self.uiState = uiState
        self.settingsWindowController = settings
        self.panelController = panel

        KeyboardShortcuts.onKeyDown(for: .toggleQuickAsk) { [weak panel] in panel?.toggle() }
        FileLog.info("Quick Ask started")
    }

    // Launching the app again while it runs toggles the panel. A regular app shows it instead:
    // a Dock click activates the app first, which already showed the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if AppMode.isMenuBarApp() { panelController?.toggle() } else { panelController?.show() }
        return false
    }

    // A regular app picked in Cmd+Tab or the Dock brings the panel, unless Settings is what activated it.
    func applicationDidBecomeActive(_ notification: Notification) {
        guard !AppMode.isMenuBarApp(), settingsWindowController?.isWindowVisible != true else { return }
        panelController?.show()
    }
}
