import AppKit
import SwiftUI

// One chat entry: a right-aligned bubble for the user, plain markdown for Claude, a muted line for errors.
struct MessageRow: View {
    let message: ChatMessage
    let isResponding: Bool

    @AppStorage(SettingsKey.fontSize) private var fontSize = SettingsDefault.fontSize
    @AppStorage(SettingsKey.showTurnCost) private var showsTurnCost = SettingsDefault.showTurnCost

    var body: some View {
        switch message.role {
        case .user: userRow
        case .assistant: assistantRow
        case .error:
            Text(message.text)
                .font(.system(size: fontSize - 1))
                .foregroundStyle(ChatPalette.secondaryText)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var userRow: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 40)
            VStack(alignment: .leading, spacing: 8) {
                if !message.images.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(message.images) { attachment in
                            if let image = NSImage(data: attachment.data) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                if !message.text.isEmpty {
                    Text(message.text).textSelection(.enabled)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                ChatPalette.userBubble,
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 16, bottomLeadingRadius: 16, bottomTrailingRadius: 4, topTrailingRadius: 16)
            )
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var assistantRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            if message.text.isEmpty {
                if isResponding { ThinkingIndicator() }
            } else {
                MarkdownView(message.text)
            }
            if showsTurnCost, let cost = message.cost {
                TurnCostCaption(cost: cost)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// Pulsing sparkle shown while Claude has not produced text yet.
private struct ThinkingIndicator: View {
    @State private var isDim = false

    var body: some View {
        Text("✦")
            .foregroundStyle(ChatPalette.accent)
            .opacity(isDim ? 0.3 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isDim)
            .onAppear { isDim = true }
    }
}
