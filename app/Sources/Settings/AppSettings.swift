import AppKit
import KeyboardShortcuts

// Every UserDefaults key the app reads or writes.
enum SettingsKey {
    static let defaultModel = "defaultModel"
    static let effort = "effort"
    static let fontSize = "fontSize"
    static let menuBarApp = "menuBarApp"
    static let showTurnCost = "showTurnCost"
    static let showTurnTokens = "showTurnTokens"
    static let claudePath = "claudePath"
    static let systemPrompt = "systemPrompt"
}

enum SettingsDefault {
    // The model the last chat started with; the panel model menu and the Settings picker both write it
    static let defaultModel = "sonnet"
    // low, medium or high
    static let effort = "low"
    static let fontSize: Double = 13
    static let fontSizeRange: ClosedRange<Double> = 9...24
    // On: no Dock icon, panel floats above other apps. Off: Dock icon, Cmd+Tab entry, normal window level
    static let menuBarApp = true
    static let showTurnCost = true
    static let showTurnTokens = false
    // Empty means auto-detect
    static let claudePath = ""
    static let systemPrompt =
        "You are Claude, a helpful assistant. Be concise. You have no tools, no file access, no code execution. Never pretend to run commands or access files."
}

// A model the picker offers; ids are CLI aliases.
struct ModelOption: Identifiable, Hashable {
    let id: String
    let label: String

    static let all: [ModelOption] = [
        ModelOption(id: "haiku", label: "Haiku"),
        ModelOption(id: "sonnet", label: "Sonnet"),
        ModelOption(id: "opus", label: "Opus"),
    ]

    // Label for an alias or a full model ID (claude-haiku-5-5); unknown ids come back unchanged.
    static func label(forModelID id: String) -> String {
        let lowered = id.lowercased()
        for option in all where lowered.contains(option.id) { return option.label }
        return id
    }
}

extension KeyboardShortcuts.Name {
    static let toggleQuickAsk = Self("toggleQuickAsk", default: .init(.a, modifiers: [.control, .command]))
}

// The "Menu bar app" setting decides the Dock and Cmd+Tab presence and the panel's window level.
enum AppMode {
    static func isMenuBarApp(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: SettingsKey.menuBarApp) as? Bool ?? SettingsDefault.menuBarApp
    }

    // macOS lists in Cmd+Tab only the apps that have a Dock icon, so both come with `.regular`.
    static func activationPolicy(isMenuBarApp: Bool) -> NSApplication.ActivationPolicy {
        isMenuBarApp ? .accessory : .regular
    }

    // A menu bar app floats above other apps; a regular app's window can be covered.
    static func panelLevel(isMenuBarApp: Bool) -> NSWindow.Level {
        isMenuBarApp ? .floating : .normal
    }
}
