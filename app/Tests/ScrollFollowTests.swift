import Testing

@testable import QuickAsk

private func geo(_ maxY: Double, content: Double, height: Double = 400) -> ScrollFollow.Geometry {
    .init(visibleMaxY: maxY, contentHeight: content, containerHeight: height, containerWidth: 500)
}

@Test func followsGrowthWhilePinned() {
    var follow = ScrollFollow()
    #expect(follow.geometryChanged(from: geo(400, content: 400), to: geo(400, content: 520)) == .toBottom)
    #expect(follow.isPinned)
}

@Test func wheelScrollAwayWithoutPhaseUnpinsAndStays() {
    var follow = ScrollFollow()
    #expect(follow.geometryChanged(from: geo(1000, content: 1000), to: geo(700, content: 1000)) == .none)
    #expect(!follow.isPinned)
    #expect(follow.geometryChanged(from: geo(700, content: 1000), to: geo(700, content: 1600)) == .none)
}

@Test func ownScrollToBottomIsNotAUserScroll() {
    var follow = ScrollFollow()
    _ = follow.geometryChanged(from: geo(400, content: 400), to: geo(400, content: 520))  // asks .toBottom
    #expect(follow.geometryChanged(from: geo(400, content: 520), to: geo(460, content: 520)) == .none)
    #expect(follow.isPinned)  // halfway there, still awaiting
}

@Test func userScrollBackToEndPins() {
    var follow = ScrollFollow()
    _ = follow.geometryChanged(from: geo(1000, content: 1000), to: geo(600, content: 1000))
    _ = follow.geometryChanged(from: geo(600, content: 1000), to: geo(990, content: 1000))
    #expect(follow.isPinned)
}

@Test func pinAfterSend() {
    var follow = ScrollFollow()
    _ = follow.geometryChanged(from: geo(1000, content: 1000), to: geo(600, content: 1000))
    #expect(follow.pinAndScroll() == .toBottom)
    #expect(follow.geometryChanged(from: geo(600, content: 1000), to: geo(600, content: 1200)) == .toBottom)
}

@Test func viewportResizeWhilePinnedScrollsAfterLayout() {
    var follow = ScrollFollow()
    #expect(follow.geometryChanged(from: geo(400, content: 900), to: geo(300, content: 900, height: 300)) == .toBottomAfterLayout)
}

@Test func growthDuringUserDragFollowsOnlyAtBottom() {
    var follow = ScrollFollow()
    follow.userScrolling(true)
    #expect(follow.geometryChanged(from: geo(700, content: 1000), to: geo(700, content: 1200)) == .none)
    #expect(!follow.isPinned)
}
