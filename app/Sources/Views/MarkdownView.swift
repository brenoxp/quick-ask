import SwiftUI
import Textual

// Claude's markdown through Textual: tables, nested lists, headings, block quotes and code blocks
// with a copy button. Links open in the system browser; text is selectable.
struct MarkdownView: View {
    let markdown: String

    init(_ markdown: String) {
        self.markdown = markdown
    }

    var body: some View {
        StructuredText(markdown: markdown)
            .textual.structuredTextStyle(.default)
            .textual.inlineStyle(
                InlineStyle.default
                    .code(.monospaced, .fontScale(0.94), .backgroundColor(ChatPalette.inlineCodeBackground))
            )
            .textual.codeBlockStyle(CopyableCodeBlockStyle())
            .textual.textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CopyableCodeBlockStyle: StructuredText.CodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        CodeBlockWithCopy(configuration: configuration)
    }
}

// Monospaced code on a faint background that scrolls sideways for long lines, with a copy button
// at the top-right corner while hovering.
private struct CodeBlockWithCopy: View {
    let configuration: StructuredText.CodeBlockStyleConfiguration

    @State private var isHovering = false
    @State private var didCopy = false

    // How long the checkmark replaces the copy icon
    private static let confirmation: Duration = .milliseconds(1500)

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            configuration.label
                .textual.fontScale(0.9)
                .fixedSize(horizontal: false, vertical: true)
                .monospaced()
                .padding(10)
        }
        .overlay(alignment: .topTrailing) {
            if isHovering || didCopy {
                Button {
                    configuration.codeBlock.copyToPasteboard()
                    didCopy = true
                    Task {
                        try? await Task.sleep(for: Self.confirmation)
                        didCopy = false
                    }
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .imageScale(.small)
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(ChatPalette.secondaryText)
                .help("Copy")
                .padding(2)
            }
        }
        .onHover { isHovering = $0 }
        .background(ChatPalette.codeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .textual.blockSpacing(.fontScaled(top: 0.8, bottom: 0))
    }
}

// Markdown sample shared by the previews: heading, nested bullets, a table, inline code.
enum PreviewMarkdown {
    static let sample = """
        # Daemon vs agent

        - launchd jobs
          - **daemon**: runs as root
          - **agent**: runs per user

        | Kind | Runs as | Location |
        |------|---------|----------|
        | Daemon | root | `/Library/LaunchDaemons` |
        | Agent | user | `~/Library/LaunchAgents` |

        > Use an agent for anything with a GUI.

        ```sh
        launchctl bootstrap gui/501 job.plist
        ```
        """
}

#Preview {
    ScrollView {
        MarkdownView(PreviewMarkdown.sample).padding()
    }
    .frame(width: 520, height: 480)
    .background(ChatPalette.background)
    .preferredColorScheme(.dark)
}
