# Quick Ask

Native macOS menu bar app with a floating chat panel toggled by Ctrl+Cmd+A,
driving one `claude -p` process per conversation over stream-json.

## Stack
SwiftUI + AppKit, Swift 6 strict concurrency, macOS 26, XcodeGen, mise, Swift
Testing. Packages: Textual (markdown), KeyboardShortcuts (hotkey).

## Commands
`mise run gen|build|test|run|install` (run `gen` after adding or removing files
or editing `app/project.yml`).

## Layout (`app/Sources/`)
- `App/`: app entry, panel, panel controller, hotkey, Settings window controller,
  `FileLog`.
- `Claude/`: `claude` child process, stream-json parsing, launch flags and env.
- `Chat/`: `ChatStore`, messages, turn cost, scroll-follow rule, image attachments.
- `Settings/`: every `UserDefaults` key (`AppSettings.swift`), Settings view.
- `Views/`: chat window, message list, markdown (Textual), composer, model menu.

## Behavior
- Panel keys: Enter sends, Shift+Enter newline, Esc and Cmd+W hide, Cmd+N new
  chat, Cmd+= / Cmd+- font size, Cmd+, Settings, Cmd+V pastes images.
- The "Menu bar app" setting (`AppMode`) is live: on, the app is `.accessory`
  with a floating panel; off, it is `.regular` (Cmd+Tab lists only Dock apps),
  the panel is `.normal` level and activating the app shows the panel.
- As a menu bar app it is never active while the panel is up, so the main menu
  delivers no key equivalents: `QuickAskPanel.performKeyEquivalent` handles
  every Cmd shortcut, edit ones (copy, paste, undo) included.
- Model is picked before the first message, locked after it, and the last pick
  is remembered (`defaultModel`). Effort, system prompt and Claude path apply to
  the next new chat (they are launch flags).
- stream-json `result.total_cost_usd` is cumulative per process; `usage` is per
  turn.

## Notes
- App is not sandboxed (it spawns `claude`).
- Log: `~/Library/Logs/quick-ask.log` (via `FileLog`, never `print`); test runs
  write `quick-ask-tests.log` instead.
- `mise run install` puts the app in `/Applications`.

## SwiftUI gotchas
- Message list is an eager `VStack`: Textual leaves rows a `LazyVStack` creates
  during updates blank.
- On macOS 26 a `ScrollView` touching the title bar safe area extends under it;
  the divider above the list keeps them apart (`ChatWindowLayoutTests`).
- A grouped `Form` has no ideal height: the Settings view sets its own frame.
- `NSTextView()` is TextKit 1 (`textLayoutManager` nil); the composer uses
  `init(usingTextLayoutManager: true)` so `sizeThatFits` can measure it.
