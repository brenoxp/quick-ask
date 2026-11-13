import Foundation

enum ClaudeLaunchError: LocalizedError {
    case executableNotFound

    var errorDescription: String? {
        switch self {
        case .executableNotFound:
            "Could not find the claude CLI. Set its location in Settings > Claude path."
        }
    }
}

/// Command line and environment for one `claude -p` stream-json conversation process.
/// The flags keep each turn cheap: no settings, tools, MCP, slash commands or session file, a fixed name,
/// thinking off and a 5-minute prompt cache.
struct ClaudeLaunchConfiguration: Sendable {
    var executablePath: String
    var model: String
    var effort: String
    var systemPrompt: String

    var arguments: [String] {
        [
            "-p",
            "--verbose",
            "--input-format", "stream-json",
            "--output-format", "stream-json",
            "--include-partial-messages",
            "--model", model,
            "--effort", effort,
            "--name", "quick-ask",
            "--system-prompt", systemPrompt,
            "--tools", "",
            "--setting-sources", "",
            "--strict-mcp-config",
            "--disable-slash-commands",
            "--no-session-persistence",
        ]
    }

    /// The child's whole environment, built from HOME and USER in `base`.
    func environment(base: [String: String]) -> [String: String] {
        let home = base["HOME"] ?? NSHomeDirectory()
        let user = base["USER"] ?? NSUserName()
        return [
            "HOME": home,
            "USER": user,
            "LANG": "en_US.UTF-8",
            "PATH": Self.searchDirectories(home: home, user: user).joined(separator: ":") + ":/usr/bin:/bin",
            "CLAUDE_CODE_DISABLE_THINKING": "1",
            "CLAUDE_CODE_PROMPT_CACHE_TTL": "5m",
            "CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION": "false",
            "CLAUDE_CODE_ENABLE_AWAY_SUMMARY": "false",
        ]
    }

    /// Reads effort, system prompt and Claude path from `defaults`. An empty Claude path means auto-detect.
    static func fromSettings(_ defaults: UserDefaults, model: String) throws -> ClaudeLaunchConfiguration {
        let configuredPath = (defaults.string(forKey: SettingsKey.claudePath) ?? SettingsDefault.claudePath)
            .trimmingCharacters(in: .whitespaces)
        let executablePath: String
        if configuredPath.isEmpty {
            guard let detected = detectedExecutable() else { throw ClaudeLaunchError.executableNotFound }
            executablePath = detected
        } else {
            executablePath = (configuredPath as NSString).expandingTildeInPath
        }
        return ClaudeLaunchConfiguration(
            executablePath: executablePath,
            model: model,
            effort: defaults.string(forKey: SettingsKey.effort) ?? SettingsDefault.effort,
            systemPrompt: defaults.string(forKey: SettingsKey.systemPrompt) ?? SettingsDefault.systemPrompt
        )
    }

    /// The first executable `claude` in the usual install locations, or nil.
    static func detectedExecutable() -> String? {
        searchDirectories(home: NSHomeDirectory(), user: NSUserName())
            .map { "\($0)/claude" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Install locations, in lookup order: the native installer, Homebrew, nix-darwin system and per-user profiles.
    private static func searchDirectories(home: String, user: String) -> [String] {
        [
            "\(home)/.local/bin",
            "/opt/homebrew/bin",
            "/run/current-system/sw/bin",
            "/etc/profiles/per-user/\(user)/bin",
        ]
    }
}
