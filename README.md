# Quick Ask

A macOS menu bar app that opens a floating chat panel for the `claude` CLI.

<!-- Screenshot of the chat panel goes here: docs/screenshot.png -->

## What it does

- Press Ctrl+Cmd+A anywhere to show or hide the chat panel.
- Each conversation runs its own `claude -p` process, so it uses your existing Claude Code login.
- Answers render as markdown, with tables and code blocks.
- Paste images with Cmd+V to ask about them.
- Pick the model before the first message. The app remembers your last pick.
- Optional per-answer cost and token counts.
- Settings (Cmd+,) cover the model, effort, system prompt, `claude` path, font size, window level and menu bar mode.

Keys in the panel: Enter sends, Shift+Enter adds a newline, Esc or Cmd+W hides the panel, Cmd+N starts a new chat, Cmd+= and Cmd+- change the font size.

## Requirements

- macOS 26
- Xcode with the Swift 6 toolchain
- [mise](https://mise.jdx.dev) and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- The [Claude Code](https://claude.com/claude-code) CLI, installed and logged in

## Build

```sh
mise run gen      # generate app/QuickAsk.xcodeproj
mise run build    # Debug build
mise run test     # unit tests
mise run run      # build and open the app without taking focus
mise run install  # Release build into /Applications
```

The project uses automatic signing. Set `DEVELOPMENT_TEAM` in `app/project.yml` to your own Apple team ID before building.

## Notes

The app is not sandboxed because it starts the `claude` process. Logs go to `~/Library/Logs/quick-ask.log`.

## How it was built

Built with Claude Code agents.

## License

MIT, see [LICENSE](LICENSE).
