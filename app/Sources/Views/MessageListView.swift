import SwiftUI

// The scrolling conversation. While the reader is at the end, new content keeps the end in view;
// scrolling away stops following, and a jump button brings the end back.
struct MessageListView: View {
    let store: ChatStore

    @State private var follow = ScrollFollow()
    @State private var position = ScrollPosition()
    @State private var geometry = ScrollFollow.Geometry(
        visibleMaxY: 0, contentHeight: 0, containerHeight: 0, containerWidth: 0)

    private static let bottomAnchorID = "bottom"

    var body: some View {
        ScrollView {
            if store.messages.isEmpty {
                emptyState
            } else {
                // Eager stack: Textual leaves rows a lazy stack creates during updates blank (textual#84).
                VStack(spacing: 12) {
                    ForEach(store.messages) { message in
                        MessageRow(
                            message: message,
                            isResponding: store.isResponding && message.id == store.messages.last?.id)
                    }
                    Color.clear.frame(height: 1).id(Self.bottomAnchorID)
                }
                .padding(16)
            }
        }
        .scrollPosition($position)
        .defaultScrollAnchor(.bottom, for: .initialOffset)
        .onScrollGeometryChange(for: ScrollFollow.Geometry.self) { scrollGeometry in
            ScrollFollow.Geometry(
                visibleMaxY: Double(scrollGeometry.visibleRect.maxY),
                contentHeight: Double(scrollGeometry.contentSize.height),
                containerHeight: Double(scrollGeometry.containerSize.height),
                containerWidth: Double(scrollGeometry.containerSize.width))
        } action: { old, new in
            var next = follow
            let action = next.geometryChanged(from: old, to: new)
            if next != follow { follow = next }
            if new != geometry { geometry = new }
            perform(action)
        }
        .onScrollPhaseChange { _, phase in
            let isScrolling = [ScrollPhase.tracking, .interacting, .decelerating].contains(phase)
            follow.userScrolling(isScrolling)
        }
        .onChange(of: store.messages.count) { old, new in
            // A new user message at the end-but-one means the person just sent
            guard new > old, new >= 2, store.messages[new - 2].role == .user else { return }
            pinAndScroll()
        }
        .overlay(alignment: .bottomTrailing) {
            if ScrollFollow.showsJumpButton(geometry) || (!follow.isPinned && store.isResponding) {
                Button(action: pinAndScroll) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(ChatPalette.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(12)
                .help("Jump to the latest message")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Ask anything")
                .font(.title3)
            Text("Press Ctrl+Cmd+A to show or hide this window")
                .font(.caption)
        }
        .foregroundStyle(ChatPalette.secondaryText)
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    private func pinAndScroll() {
        var next = follow
        let action = next.pinAndScroll()
        follow = next
        perform(action)
    }

    private func perform(_ action: ScrollFollow.Scroll) {
        switch action {
        case .none:
            break
        case .toBottom:
            scrollToBottom()
        case .toBottomAfterLayout:
            Task { @MainActor in scrollToBottom() }
        }
    }

    private func scrollToBottom() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { position.scrollTo(edge: .bottom) }
    }
}
