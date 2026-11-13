import KeyboardShortcuts
import ServiceManagement
import SwiftUI

// The Settings window content: four tabs, every control bound to a SettingsKey.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            ChatSettingsTab()
                .tabItem { Label("Chat", systemImage: "text.bubble") }
            CostSettingsTab()
                .tabItem { Label("Cost", systemImage: "dollarsign.circle") }
            AdvancedSettingsTab()
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .formStyle(.grouped)
        // A grouped Form scrolls and has no ideal height; the window sizes itself from this frame.
        .frame(width: 480, height: 440)
    }
}

private let nextChatFootnote = "Applies to the next new chat."

private struct GeneralSettingsTab: View {
    @AppStorage(SettingsKey.menuBarApp) private var isMenuBarApp = SettingsDefault.menuBarApp
    @AppStorage(SettingsKey.defaultModel) private var defaultModel = SettingsDefault.defaultModel
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchError: String?

    var body: some View {
        Form {
            KeyboardShortcuts.Recorder("Toggle Quick Ask", name: .toggleQuickAsk)
            Section {
                Toggle("Menu bar app", isOn: $isMenuBarApp)
            } footer: {
                Text("On: the window floats above other apps, and Quick Ask stays out of the Dock and Cmd+Tab. Off: a regular window, listed in the Dock and Cmd+Tab.")
            }
            Section {
                Toggle("Launch at login", isOn: launchAtLoginBinding)
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.red)
                }
            }
            Section {
                Picker("Default model", selection: $defaultModel) {
                    ForEach(ModelOption.all) { option in
                        Text(option.label).tag(option.id)
                    }
                }
            } footer: {
                Text(nextChatFootnote)
            }
        }
        .onAppear { launchesAtLogin = SMAppService.mainApp.status == .enabled }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchesAtLogin },
            set: { wanted in
                do {
                    if wanted {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    launchError = nil
                } catch {
                    launchError = error.localizedDescription
                    FileLog.error("launch at login change failed: \(error.localizedDescription)")
                }
                launchesAtLogin = SMAppService.mainApp.status == .enabled
            }
        )
    }
}

private struct ChatSettingsTab: View {
    @AppStorage(SettingsKey.fontSize) private var fontSize = SettingsDefault.fontSize
    @AppStorage(SettingsKey.effort) private var effort = SettingsDefault.effort
    @AppStorage(SettingsKey.systemPrompt) private var systemPrompt = SettingsDefault.systemPrompt

    var body: some View {
        Form {
            Stepper(value: $fontSize, in: SettingsDefault.fontSizeRange, step: 1) {
                Text("Font size: \(Int(fontSize)) pt")
            }
            Section {
                Picker("Effort", selection: $effort) {
                    Text("Low").tag("low")
                    Text("Medium").tag("medium")
                    Text("High").tag("high")
                }
            } footer: {
                Text(nextChatFootnote)
            }
            Section {
                TextEditor(text: $systemPrompt)
                    .font(.body)
                    .frame(height: 6 * 17)
                HStack {
                    Spacer()
                    Button("Reset") { systemPrompt = SettingsDefault.systemPrompt }
                        .disabled(systemPrompt == SettingsDefault.systemPrompt)
                }
            } header: {
                Text("System prompt")
            } footer: {
                Text(nextChatFootnote)
            }
        }
    }
}

private struct CostSettingsTab: View {
    @AppStorage(SettingsKey.showTurnCost) private var showsTurnCost = SettingsDefault.showTurnCost
    @AppStorage(SettingsKey.showTurnTokens) private var showsTokens = SettingsDefault.showTurnTokens

    var body: some View {
        Form {
            Toggle("Show turn cost in chat", isOn: $showsTurnCost)
            Toggle("Show tokens", isOn: $showsTokens)
                .disabled(!showsTurnCost)
        }
    }
}

private struct AdvancedSettingsTab: View {
    @AppStorage(SettingsKey.claudePath) private var claudePath = SettingsDefault.claudePath

    var body: some View {
        Form {
            Section {
                TextField(
                    "Claude path",
                    text: $claudePath,
                    prompt: Text(ClaudeLaunchConfiguration.detectedExecutable() ?? "claude not found")
                )
            } footer: {
                Text(nextChatFootnote)
            }
            Button("Open log") {
                let logURL = FileManager.default.homeDirectoryForCurrentUser
                    .appending(path: "Library/Logs/quick-ask.log")
                NSWorkspace.shared.open(logURL)
            }
        }
    }
}
