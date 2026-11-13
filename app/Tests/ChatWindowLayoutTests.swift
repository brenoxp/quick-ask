import AppKit
import SwiftUI
import Testing
@testable import QuickAsk

@MainActor private final class IdleSession: ClaudeSession {
    var isRunning = false
    func start() throws { isRunning = true }
    func send(_ line: Data) throws {}
    func stop() { isRunning = false }
}

private func scrollViews(in view: NSView) -> [NSScrollView] {
    view.subviews.flatMap { ($0 as? NSScrollView).map { [$0] } ?? [] + scrollViews(in: $0) }
}

// The panel's title bar is transparent; a scroll view reaching under it lets messages pass behind the title.
@MainActor
@Test func messageListStaysBelowTitleBar() throws {
    let store = ChatStore(makeSession: { _, _, _ in IdleSession() })
    store.send(text: "hi", images: [])
    store.handle(.textDelta(Array(repeating: "A long answer line.", count: 40).joined(separator: "\n\n")))
    let panel = QuickAskPanel()
    panel.setFrame(NSRect(x: 0, y: 0, width: 500, height: 600), display: false)
    let host = NSHostingView(rootView: ChatWindowView(store: store, uiState: PanelUIState()))
    panel.contentView = host
    host.layoutSubtreeIfNeeded()

    let titleBarHeight = host.safeAreaInsets.top
    #expect(titleBarHeight > 0)
    let found = scrollViews(in: host)
    #expect(!found.isEmpty)
    for scrollView in found {
        let frame = scrollView.convert(scrollView.bounds, to: host)
        #expect(frame.minY >= titleBarHeight)
    }
}
