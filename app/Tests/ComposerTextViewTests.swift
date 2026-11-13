import AppKit
import SwiftUI
import Testing
@testable import QuickAsk

@MainActor
private func composerFieldHeight(text: String) -> CGFloat? {
    let field = ComposerTextView(text: .constant(text), fontSize: 13, focusRequest: 0, onSubmit: {}, onImages: { _ in })
    let host = NSHostingView(rootView: VStack(spacing: 0) { Color.clear; field }.frame(width: 400, height: 600))
    host.layoutSubtreeIfNeeded()
    let scrollView = host.subviews.flatMap { [$0] + $0.subviews }.first { $0 is NSScrollView }
    return scrollView?.frame.height
}

@MainActor
@Test func composerFieldIsOneLineTallWhenEmpty() throws {
    let height = try #require(composerFieldHeight(text: ""))
    #expect(height < 50)
}

@MainActor
@Test func composerFieldStopsGrowingAtMaxHeight() throws {
    let longText = Array(repeating: "line", count: 20).joined(separator: "\n")
    let height = try #require(composerFieldHeight(text: longText))
    #expect(height == ComposerTextView.maxHeight)
}
