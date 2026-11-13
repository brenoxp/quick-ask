import Foundation
import Testing

@testable import QuickAsk

@Test func modelLabelsFromFullIDsAndAliases() {
    #expect(ModelOption.label(forModelID: "claude-haiku-5-5") == "Haiku")
    #expect(ModelOption.label(forModelID: "opus") == "Opus")
    #expect(ModelOption.label(forModelID: "x") == "x")
}

// Cmd+Tab lists only apps with a Dock icon, so turning "Menu bar app" off must make the app regular.
@Test func menuBarAppSettingDecidesDockPresenceAndLevel() throws {
    let defaults = try #require(UserDefaults(suiteName: "QuickAskTests.appMode"))
    defaults.removePersistentDomain(forName: "QuickAskTests.appMode")
    #expect(AppMode.isMenuBarApp(defaults))

    defaults.set(false, forKey: SettingsKey.menuBarApp)
    #expect(!AppMode.isMenuBarApp(defaults))
    #expect(AppMode.activationPolicy(isMenuBarApp: false) == .regular)
    #expect(AppMode.panelLevel(isMenuBarApp: false) == .normal)
    #expect(AppMode.activationPolicy(isMenuBarApp: true) == .accessory)
    #expect(AppMode.panelLevel(isMenuBarApp: true) == .floating)
    defaults.removePersistentDomain(forName: "QuickAskTests.appMode")
}
