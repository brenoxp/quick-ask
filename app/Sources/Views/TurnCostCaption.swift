import SwiftUI

// Cost line under an assistant answer. Clicking it opens a menu with the two cost switches; a menu,
// unlike a popover, does not activate the app.
struct TurnCostCaption: View {
    let cost: TurnCost

    @AppStorage(SettingsKey.showTurnCost) private var showsTurnCost = SettingsDefault.showTurnCost
    @AppStorage(SettingsKey.showTurnTokens) private var showsTokens = SettingsDefault.showTurnTokens

    var body: some View {
        Menu {
            Toggle("Show turn cost in chat", isOn: $showsTurnCost)
            Toggle("Show tokens", isOn: $showsTokens)
                .disabled(!showsTurnCost)
        } label: {
            Text(CostFormat.caption(cost, showsTokens: showsTokens))
                .font(.caption)
                .foregroundStyle(ChatPalette.secondaryText)
        }
        // A plain button style drops the borderless style's inner padding, so the label lines up with the text around it.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(CostFormat.help(cost))
    }
}
