import SwiftUI

// Colors of the chat views (hex RGB).
enum ChatPalette {
    static let background = Color(hex: 0x2B2A27)
    static let userBubble = Color(hex: 0x393937)
    static let accent = Color(hex: 0xD97756)
    static let secondaryText = Color(hex: 0x9A9893)
    static let divider = Color(hex: 0x3A3936)
    static let codeBackground = Color(hex: 0x1A1918)
    static let inlineCodeBackground = Color(hex: 0x3A3936)
    static let tableBorder = Color(hex: 0x4A4845)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255)
    }
}

// The panel's content: message list on top, composer below.
struct ChatWindowView: View {
    let store: ChatStore
    let uiState: PanelUIState

    @AppStorage(SettingsKey.fontSize) private var fontSize = SettingsDefault.fontSize

    init(store: ChatStore, uiState: PanelUIState) {
        self.store = store
        self.uiState = uiState
    }

    var body: some View {
        VStack(spacing: 0) {
            // A scroll view touching the title bar's safe area extends under it; the divider keeps them apart.
            Rectangle().fill(ChatPalette.divider).frame(height: 1)
            MessageListView(store: store)
            Rectangle().fill(ChatPalette.divider).frame(height: 1)
            ComposerView(store: store, uiState: uiState)
        }
        // Content stays below the transparent title bar; only the background fills it.
        .background(ChatPalette.background.ignoresSafeArea())
        .font(.system(size: fontSize))
        .preferredColorScheme(.dark)
    }
}

// Session that accepts every line and never answers, so previews can feed events by hand.
@MainActor private final class PreviewSession: ClaudeSession {
    var isRunning = true
    func start() throws {}
    func send(_ line: Data) throws {}
    func stop() {}
}

@MainActor private func previewStore() -> ChatStore {
    ChatStore(makeSession: { _, _, _ in PreviewSession() })
}

#Preview("Conversation") {
    let store = previewStore()
    store.send(text: "What is the difference between a daemon and an agent?", images: [])
    store.handle(.textDelta(PreviewMarkdown.sample))
    return ChatWindowView(store: store, uiState: PanelUIState())
        .frame(width: 520, height: 640)
}

#Preview("Empty") {
    ChatWindowView(store: previewStore(), uiState: PanelUIState())
        .frame(width: 520, height: 640)
}
