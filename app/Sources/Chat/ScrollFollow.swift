import Foundation

// The chat's follow-the-bottom rule, kept free of views so it can be tested. `isPinned` is true
// while the person reads the end of the chat; while pinned, every change of the content or the
// viewport keeps the end in view. Scrolling away unpins; scrolling back to the end, the jump
// button or sending a prompt pins again.
struct ScrollFollow: Equatable {
    // How close to the end of the content (in points) still counts as "at the bottom"
    static let bottomTolerance: Double = 24
    // A gap below this means the view already shows the end of the content
    static let settledGap: Double = 0.5

    // One reading of the chat's scroll view
    struct Geometry: Equatable {
        var visibleMaxY: Double
        var contentHeight: Double
        var containerHeight: Double
        var containerWidth: Double

        // Points of content below the visible area (0 when the content is shorter than the view)
        var gapBelow: Double { max(0, contentHeight - visibleMaxY) }
        var isAtBottom: Bool { gapBelow <= ScrollFollow.bottomTolerance }
    }

    // What the view does after an event
    enum Scroll: Equatable {
        case none
        // Scroll to the end now, without animation
        case toBottom
        // Scroll to the end once the current layout pass has settled
        case toBottomAfterLayout
    }

    private(set) var isPinned = true
    // A scroll to the end was asked for and has not landed; offset moves until then are the
    // view's own, never the person's
    private(set) var isAwaitingBottom = false
    // A drag, wheel or momentum scroll by the person is running
    private(set) var isUserScrolling = false

    // Sending a prompt or pressing the jump button: the chat follows from wherever the person was
    mutating func pinAndScroll() -> Scroll {
        isUserScrolling = false
        isPinned = true
        return awaitBottom(.toBottom)
    }

    // The person started (true) or ended (false) a drag, wheel or momentum scroll
    mutating func userScrolling(_ isScrolling: Bool) {
        isUserScrolling = isScrolling
        if isScrolling { isAwaitingBottom = false }
    }

    // One scroll geometry change
    mutating func geometryChanged(from old: Geometry, to new: Geometry) -> Scroll {
        if old.containerHeight != new.containerHeight {
            return isPinned ? awaitBottom(.toBottomAfterLayout) : .none
        }
        if old.containerWidth != new.containerWidth {
            return isPinned ? awaitBottom(.toBottom) : .none
        }
        if old.contentHeight != new.contentHeight {
            if isUserScrolling {
                isPinned = new.isAtBottom
                return .none
            }
            guard isPinned else { return .none }
            return new.gapBelow > Self.settledGap ? awaitBottom(.toBottom) : landed()
        }
        // Only the offset moved: a scroll
        if isAwaitingBottom {
            return new.gapBelow <= Self.settledGap ? landed() : .none
        }
        isPinned = new.isAtBottom
        return .none
    }

    // The jump button shows while the reader is more than one viewport above the end
    static func showsJumpButton(_ geometry: Geometry) -> Bool {
        geometry.containerHeight > 0 && geometry.gapBelow > geometry.containerHeight
    }

    private mutating func awaitBottom(_ scroll: Scroll) -> Scroll {
        isAwaitingBottom = true
        return scroll
    }

    private mutating func landed() -> Scroll {
        isAwaitingBottom = false
        return .none
    }
}
