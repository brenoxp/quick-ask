import AppKit
import SwiftUI

/// Horizontal row of pending image thumbnails, each with a remove button.
struct AttachmentStrip: View {
    let attachments: [ImageAttachment]
    let onRemove: (ImageAttachment.ID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    thumbnail(attachment)
                }
            }
            .padding(.top, 6)
            .padding(.trailing, 6)
        }
    }

    private func thumbnail(_ attachment: ImageAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = NSImage(data: attachment.data) {
                    Image(nsImage: image).resizable().scaledToFill()
                } else {
                    Color(white: 0.2)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Button {
                onRemove(attachment.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.black.opacity(0.7))
            }
            .buttonStyle(.plain)
            .offset(x: 6, y: -6)
            .help("Remove image")
        }
    }
}
