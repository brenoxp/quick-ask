import SwiftUI

/// Model picker for the composer's options row. Selectable while the chat is empty;
/// the first message locks the model for that chat.
struct ModelMenu: View {
    let store: ChatStore

    private var currentLabel: String { ModelOption.label(forModelID: store.model) }

    var body: some View {
        if store.canSelectModel {
            Menu {
                ForEach(ModelOption.all) { option in
                    Button {
                        store.selectModel(option.id)
                    } label: {
                        if option.label == currentLabel {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(currentLabel)
                    Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                }
            }
            // A plain button style drops the borderless style's inner padding, so the label lines up with the text around it.
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)
            .help("Model for this chat")
        } else {
            Text(currentLabel)
                .foregroundStyle(.secondary)
                .help("Model is fixed for this chat. Cmd+N starts a new one.")
        }
    }
}
