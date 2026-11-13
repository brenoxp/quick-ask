import SwiftUI

/// Input area: pending image thumbnails, the text box with the send button, and the model menu.
struct ComposerView: View {
    let store: ChatStore
    let uiState: PanelUIState

    @AppStorage(SettingsKey.fontSize) private var fontSize = SettingsDefault.fontSize
    @State private var text = ""
    @State private var attachments: [ImageAttachment] = []
    @State private var isFieldFocused = false

    private static let fieldBackground = Color(hex: 0x1F1E1B)

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool {
        !store.isResponding && (!trimmedText.isEmpty || !attachments.isEmpty)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !attachments.isEmpty {
                AttachmentStrip(attachments: attachments) { id in
                    attachments.removeAll { $0.id == id }
                }
            }
            HStack(alignment: .bottom, spacing: 8) {
                ComposerTextView(
                    text: $text,
                    fontSize: fontSize,
                    focusRequest: uiState.focusRequest,
                    onSubmit: submit,
                    onImages: { attachments.append(contentsOf: $0) },
                    onFocusChange: { isFieldFocused = $0 })
                .background(RoundedRectangle(cornerRadius: 16).fill(Self.fieldBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isFieldFocused ? ChatPalette.accent : ChatPalette.tableBorder, lineWidth: 1))
                sendButton
            }
            HStack {
                ModelMenu(store: store)
                Spacer()
            }
            .font(.system(size: 11))
            .padding(.leading, ComposerTextView.horizontalInset)
        }
        // Same side margin as the message list, so the field and the send button line up with the messages.
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onChange(of: store.chatID) {
            text = ""
            attachments = []
        }
    }

    private var sendButton: some View {
        Button(action: submit) {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(canSend ? Color(red: 0.851, green: 0.459, blue: 0.337) : Color(red: 0.29, green: 0.282, blue: 0.271)))
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .help("Send (Enter)")
    }

    private func submit() {
        guard canSend else { return }
        store.send(text: trimmedText, images: attachments)
        text = ""
        attachments = []
    }
}
