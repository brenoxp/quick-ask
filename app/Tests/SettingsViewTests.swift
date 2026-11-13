import AppKit
import SwiftUI
import Testing
@testable import QuickAsk

// The Settings window takes its size from the view; a grouped Form alone has no ideal height.
@MainActor
@Test func settingsViewHasRoomForItsForms() {
    let controller = NSHostingController(rootView: SettingsView())
    #expect(controller.view.fittingSize.height > 300)
}
