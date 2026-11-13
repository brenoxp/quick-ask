import AppKit
import SwiftUI
import Testing
@testable import QuickAsk

@MainActor private final class ScreenshotSession: ClaudeSession {
    var isRunning = true
    func start() throws {}
    func send(_ line: Data) throws {}
    func stop() {}
}

private let screenshotAnswer = """
    Use `lsof` to list the process that holds the port:

    ```sh
    lsof -nP -iTCP:8080 -sTCP:LISTEN
    ```

    | Flag | What it does |
    |------|--------------|
    | `-n` | skips DNS lookups |
    | `-P` | shows port numbers, not names |
    | `-sTCP:LISTEN` | keeps only listening sockets |

    The `PID` column is the process. Stop it with `kill <PID>`, or `kill -9 <PID>` if it ignores the first signal.
    """

// Renders the panel with a sample chat into the PNG named by QUICK_ASK_SCREENSHOT (run: mise run screenshot).
// Draws offscreen: no window is shown and focus never moves.
@MainActor
@Test(.enabled(if: ProcessInfo.processInfo.environment["QUICK_ASK_SCREENSHOT"] != nil))
func readmeScreenshot() throws {
    let outputPath = try #require(ProcessInfo.processInfo.environment["QUICK_ASK_SCREENSHOT"])
    let store = ChatStore(makeSession: { _, _, _ in ScreenshotSession() })
    store.send(text: "What is listening on port 8080 on my Mac, and how do I stop it?", images: [])
    store.handle(.textDelta(screenshotAnswer))
    store.handle(.turnResult(TurnResult(
        isError: false, errorText: nil, cumulativeCostUsd: 0.012,
        usage: TurnUsage(inputTokens: 1_840, outputTokens: 212, cacheReadTokens: 0, cacheWriteTokens: 0),
        models: ["claude-sonnet-5-5"])))

    let size = NSSize(width: 520, height: 560)
    let panel = QuickAskPanel()
    panel.setFrame(NSRect(origin: .zero, size: size), display: false)
    let host = NSHostingView(rootView: ChatWindowView(store: store, uiState: PanelUIState()))
    panel.contentView = host
    host.layoutSubtreeIfNeeded()
    // Markdown rows lay out asynchronously; give them a few run loop passes.
    RunLoop.main.run(until: Date().addingTimeInterval(1.5))
    host.layoutSubtreeIfNeeded()

    panel.title = PanelController.title(model: store.model, totalCostUsd: store.totalCostUsd)
    // The theme frame is the window's root view: title bar, traffic lights and content.
    let frameView = try #require(host.superview)
    frameView.layoutSubtreeIfNeeded()
    let window = try renderView(frameView, scale: 2)
    let png = try #require(framedWindow(window, pointSize: frameView.bounds.size, scale: 2))
    try png.write(to: URL(fileURLWithPath: outputPath))
}

@MainActor private func renderView(_ view: NSView, scale: Int) throws -> CGImage {
    let bitmap = try #require(NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(view.bounds.width) * scale, pixelsHigh: Int(view.bounds.height) * scale,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
    bitmap.size = view.bounds.size
    view.cacheDisplay(in: view.bounds, to: bitmap)
    return try #require(bitmap.cgImage)
}

// Draws the window the way the window server would: rounded corners, a thin edge and a drop shadow
// on a transparent margin (an offscreen render has none of them).
private func framedWindow(_ window: CGImage, pointSize: NSSize, scale: Int) -> Data? {
    let s = CGFloat(scale)
    let margin: CGFloat = 40, cornerRadius: CGFloat = 16
    let canvas = NSSize(width: pointSize.width + margin * 2, height: pointSize.height + margin * 2)
    guard let context = CGContext(
        data: nil, width: Int(canvas.width * s), height: Int(canvas.height * s), bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.scaleBy(x: s, y: s)
    let rect = CGRect(x: margin, y: margin, width: pointSize.width, height: pointSize.height)
    let shape = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 36, color: CGColor(gray: 0, alpha: 0.45))
    context.addPath(shape)
    context.setFillColor(CGColor(gray: 0, alpha: 1))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.clip()
    context.draw(window, in: rect)
    context.restoreGState()

    context.addPath(CGPath(
        roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerWidth: cornerRadius - 0.5, cornerHeight: cornerRadius - 0.5,
        transform: nil))
    context.setStrokeColor(CGColor(gray: 1, alpha: 0.16))
    context.setLineWidth(1)
    context.strokePath()

    guard let image = context.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
}
