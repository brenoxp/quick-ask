import AppKit
import Observation
import SwiftUI

// Shows, hides and titles the chat panel, and hands focus back to the app that was in front before it.
@MainActor final class PanelController: NSObject, NSWindowDelegate {
    let panel: QuickAskPanel

    private let store: ChatStore
    private let uiState: PanelUIState
    private var previousApp: NSRunningApplication?
    private var needsInitialPlacement: Bool
    private var titleTask: Task<Void, Never>?
    private var defaultsObserver: NSObjectProtocol?

    init(store: ChatStore, uiState: PanelUIState, showSettings: @escaping () -> Void) {
        self.store = store
        self.uiState = uiState
        panel = QuickAskPanel()
        needsInitialPlacement = !panel.restoredSavedFrame
        super.init()

        let hostingView = NSHostingView(rootView: ChatWindowView(store: store, uiState: uiState))
        // The panel's saved frame decides its size; the SwiftUI content only sets a minimum.
        hostingView.sizingOptions = [.minSize]
        panel.contentView = hostingView
        panel.delegate = self
        panel.onHide = { [weak self] in self?.hide() }
        panel.onNewChat = { [weak self] in self?.store.newChat() }
        panel.onShowSettings = showSettings
        panel.title = Self.title(model: store.model, totalCostUsd: store.totalCostUsd)

        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.applyAppMode() }
        }
        applyAppMode()
        observeTitle()
    }

    // Applies the "Menu bar app" setting live: Dock and Cmd+Tab presence, and the panel's level.
    func applyAppMode() {
        panel.applyLevel()
        let policy = AppMode.activationPolicy(isMenuBarApp: AppMode.isMenuBarApp())
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
    }

    // Hides the panel whenever it is in front, focused or not; a hidden or covered panel comes to the front instead.
    func toggle() {
        let isInFront = panel.isVisible
            && (AppMode.isMenuBarApp() || panel.isKeyWindow || Self.isFrontmostNormalWindow(panel.windowNumber))
        if isInFront {
            hide()
        } else {
            show()
        }
    }

    // True when no other app's normal window sits above this one. A floating panel (menu bar app)
    // is always in front, so this only matters at the normal window level.
    private static func isFrontmostNormalWindow(_ windowNumber: Int) -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]]
        else { return false }
        // The list runs front to back; the first visible normal-level window is the frontmost one.
        let frontmost = windows.first { info in
            (info[kCGWindowLayer as String] as? Int) == 0 && ((info[kCGWindowAlpha as String] as? Double) ?? 1) > 0
        }
        return (frontmost?[kCGWindowNumber as String] as? Int) == windowNumber
    }

    func show() {
        if let frontmost = NSWorkspace.shared.frontmostApplication, frontmost != NSRunningApplication.current {
            previousApp = frontmost
        }
        if needsInitialPlacement {
            placeOnFrontmostScreen()
            needsInitialPlacement = false
        }
        panel.orderFrontRegardless()
        panel.makeKey()
        // A regular app activates, so it moves to the front of Cmd+Tab; a menu bar app never does.
        if !AppMode.isMenuBarApp() { NSApp.activate() }
        uiState.requestInputFocus()
    }

    // When Settings or a menu activated the app, the previous app gets focus back,
    // so focus never stays on an app with no window in front.
    func hide() {
        panel.orderOut(nil)
        if NSApp.isActive, let previousApp { _ = previousApp.activate() }
    }

    // The red close button hides the panel and keeps the conversation.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hide()
        return false
    }

    static func title(model: String, totalCostUsd: Double) -> String {
        var text = "Quick Ask · \(ModelOption.label(forModelID: model))"
        if totalCostUsd > 0 { text += " · \(CostFormat.costText(totalCostUsd))" }
        return text
    }

    private func observeTitle() {
        let store = self.store
        titleTask = Task { [weak self] in
            let changes = Observations { @MainActor in (store.model, store.totalCostUsd) }
            for await (model, totalCostUsd) in changes {
                guard let self else { return }
                self.panel.title = Self.title(model: model, totalCostUsd: totalCostUsd)
            }
        }
    }

    // Default size, centered on the screen of the frontmost window (NSScreen.main when none is found).
    private func placeOnFrontmostScreen() {
        guard let screen = Self.frontmostWindowScreen() ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = QuickAskPanel.defaultSize
        let origin = NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
    }

    // The screen holding the center of the frontmost app's topmost normal window.
    private static func frontmostWindowScreen() -> NSScreen? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]],
              let primaryScreen = NSScreen.screens.first
        else { return nil }

        for info in windows {
            guard (info[kCGWindowOwnerPID as String] as? Int32) == pid,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let boundsDictionary = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary)
            else { continue }
            // Window list bounds use a top-left origin on the primary screen; AppKit uses bottom-left.
            let center = NSPoint(x: bounds.midX, y: primaryScreen.frame.maxY - bounds.midY)
            return NSScreen.screens.first { $0.frame.contains(center) }
        }
        return nil
    }
}
