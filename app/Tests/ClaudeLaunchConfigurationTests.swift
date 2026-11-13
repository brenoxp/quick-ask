import Foundation
import Testing

@testable import QuickAsk

@Test func argumentsMatchExpectedLaunchFlags() {
    let config = ClaudeLaunchConfiguration(executablePath: "/x/claude", model: "opus", effort: "low", systemPrompt: "Be brief.")
    let args = config.arguments
    #expect(args.starts(with: ["-p", "--verbose", "--input-format", "stream-json", "--output-format", "stream-json", "--include-partial-messages"]))
    #expect(args.contains("--no-session-persistence") && args.contains("--strict-mcp-config"))
    let model = args.firstIndex(of: "--model")!
    #expect(args[model + 1] == "opus")
    let tools = args.firstIndex(of: "--tools")!
    #expect(args[tools + 1] == "")
}

@Test func environmentAddsCostSavingFlagsAndPath() {
    let env = ClaudeLaunchConfiguration(executablePath: "/x/claude", model: "m", effort: "low", systemPrompt: "")
        .environment(base: ["HOME": "/h", "USER": "u"])
    #expect(env["CLAUDE_CODE_DISABLE_THINKING"] == "1")
    #expect(env["CLAUDE_CODE_PROMPT_CACHE_TTL"] == "5m")
    #expect(env["PATH"]!.hasPrefix("/h/.local/bin:"))
}

@Test func fromSettingsReadsStoredValues() throws {
    let suite = "quick-ask-tests-\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("/custom/claude", forKey: SettingsKey.claudePath)
    defaults.set("high", forKey: SettingsKey.effort)
    defaults.set("Answer in Portuguese.", forKey: SettingsKey.systemPrompt)

    let config = try ClaudeLaunchConfiguration.fromSettings(defaults, model: "haiku")
    #expect(config.executablePath == "/custom/claude")
    #expect(config.model == "haiku")
    #expect(config.effort == "high")
    #expect(config.systemPrompt == "Answer in Portuguese.")
}
