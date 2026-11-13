import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import QuickAsk

private func makeImage(width: Int, height: Int, noise: Bool = false) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    if noise {
        let buffer = context.data!.assumingMemoryBound(to: UInt8.self)
        let byteCount = context.bytesPerRow * height
        for index in 0..<byteCount {
            buffer[index] = index % 4 == 3 ? 255 : UInt8.random(in: 0...255)
        }
    } else {
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
    return context.makeImage()!
}

private func pngData(_ image: CGImage) -> Data {
    let output = NSMutableData()
    let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    return output as Data
}

@Test func wideImageIsDownscaledToLongEdgeLimit() throws {
    let attachment = try #require(ImageAttachmentReader.make(from: makeImage(width: 4000, height: 1000)))
    #expect(attachment.pixelWidth == 1568)
    #expect(attachment.pixelHeight == 392)
}

@Test func smallOpaqueImageKeepsSizeAndIsPNG() throws {
    let attachment = try #require(ImageAttachmentReader.make(from: makeImage(width: 100, height: 100)))
    #expect(attachment.pixelWidth == 100)
    #expect(attachment.pixelHeight == 100)
    #expect(attachment.mediaType == "image/png")
}

@Test func hugePNGFallsBackToJPEG() throws {
    let attachment = try #require(
        ImageAttachmentReader.make(from: makeImage(width: 1500, height: 1500, noise: true)))
    #expect(attachment.mediaType == "image/jpeg")
    #expect(attachment.pixelWidth == 1500)
}

@Test func payloadBase64DecodesBackToData() throws {
    let attachment = try #require(ImageAttachmentReader.make(from: makeImage(width: 50, height: 50)))
    #expect(Data(base64Encoded: attachment.payload.base64Data) == attachment.data)
    #expect(attachment.payload.mediaType == attachment.mediaType)
}

@MainActor
@Test func pasteboardWithPNGDataReturnsOneAttachment() {
    let pasteboard = NSPasteboard(name: .init(UUID().uuidString))
    pasteboard.clearContents()
    pasteboard.setData(pngData(makeImage(width: 64, height: 32)), forType: .png)
    #expect(ImageAttachmentReader.fromPasteboard(pasteboard).count == 1)
}

@MainActor
@Test func pasteboardWithOnlyStringReturnsNone() {
    let pasteboard = NSPasteboard(name: .init(UUID().uuidString))
    pasteboard.clearContents()
    pasteboard.setString("hello", forType: .string)
    #expect(ImageAttachmentReader.fromPasteboard(pasteboard).isEmpty)
}

@MainActor
@Test func pasteboardWithImageFileURLReturnsExactlyOneAttachment() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let fileURL = directory.appendingPathComponent("photo.png")
    try pngData(makeImage(width: 64, height: 32)).write(to: fileURL)

    let pasteboard = NSPasteboard(name: .init(UUID().uuidString))
    pasteboard.clearContents()
    pasteboard.writeObjects([fileURL as NSURL])
    let attachments = ImageAttachmentReader.fromPasteboard(pasteboard)
    #expect(attachments.count == 1)
    #expect(attachments.first?.pixelWidth == 64)
}
