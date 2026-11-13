import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// An image ready to send to Claude: already downscaled and encoded.
struct ImageAttachment: Identifiable, Equatable, Sendable {
    let id: UUID
    let data: Data
    let mediaType: String
    let pixelWidth: Int
    let pixelHeight: Int

    var payload: ImagePayload {
        ImagePayload(mediaType: mediaType, base64Data: data.base64EncodedString())
    }
}

enum ImageAttachmentReader {
    /// Long edge in pixels past which the API downscales images itself.
    static let maxLongEdge = 1568
    /// PNG size above which the image is encoded as JPEG instead (API limit is 5 MB).
    private static let maxPNGBytes = 3_500_000
    private static let jpegQuality = 0.85

    /// Reads image file URLs first; only when there are none, reads image objects.
    /// Reading both would attach a copied Finder file twice, or its icon.
    static func fromPasteboard(_ pasteboard: NSPasteboard) -> [ImageAttachment] {
        let urlOptions: [NSPasteboard.ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true,
            .urlReadingContentsConformToTypes: [UTType.image.identifier],
        ]
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: urlOptions) as? [URL]) ?? []
        if !urls.isEmpty {
            return urls.compactMap { url in
                guard let image = loadImage(at: url) else {
                    FileLog.warn("could not read image file: \(url.lastPathComponent)")
                    return nil
                }
                return make(from: image)
            }
        }

        let images = (pasteboard.readObjects(forClasses: [NSImage.self]) as? [NSImage]) ?? []
        return images.compactMap { image in
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
            return make(from: cgImage)
        }
    }

    /// Downscales to `maxLongEdge` when needed, then encodes PNG, or JPEG when the PNG is too large.
    static func make(from image: CGImage) -> ImageAttachment? {
        let (width, height) = targetSize(width: image.width, height: image.height)
        guard let png = encode(image, width: width, height: height, type: .png, mediaType: "image/png") else {
            return nil
        }
        if png.data.count <= maxPNGBytes {
            return attachment(png, width: width, height: height)
        }
        guard let jpeg = encode(image, width: width, height: height, type: .jpeg, mediaType: "image/jpeg") else {
            return nil
        }
        return attachment(jpeg, width: width, height: height)
    }

    private static func attachment(_ encoded: (data: Data, mediaType: String), width: Int, height: Int)
        -> ImageAttachment
    {
        ImageAttachment(
            id: UUID(), data: encoded.data, mediaType: encoded.mediaType,
            pixelWidth: width, pixelHeight: height)
    }

    private static func targetSize(width: Int, height: Int) -> (Int, Int) {
        let longEdge = max(width, height)
        guard longEdge > maxLongEdge else { return (width, height) }
        let scale = Double(maxLongEdge) / Double(longEdge)
        return (max(1, Int((Double(width) * scale).rounded())), max(1, Int((Double(height) * scale).rounded())))
    }

    /// Draws into an sRGB context of the target size and encodes it. JPEG gets a white
    /// background because it has no alpha channel.
    private static func encode(
        _ image: CGImage, width: Int, height: Int, type: UTType, mediaType: String
    ) -> (data: Data, mediaType: String)? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.interpolationQuality = .high
        if type == .jpeg {
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(rect)
        }
        context.draw(image, in: rect)
        guard let rendered = context.makeImage() else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil)
        else { return nil }
        var properties: [CFString: Any] = [:]
        if type == .jpeg { properties[kCGImageDestinationLossyCompressionQuality] = jpegQuality }
        CGImageDestinationAddImage(destination, rendered, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return (output as Data, mediaType)
    }

    /// Loads with the EXIF orientation applied, capped at `maxLongEdge`.
    private static func loadImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxLongEdge,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
