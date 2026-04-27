import XCTest
@testable import ClaudeCodeHubMobileCore

final class RecentRecordHighlighterTests: XCTestCase {
    func testInitialSnapshotDoesNotHighlightExistingRecords() {
        var highlighter = RecentRecordHighlighter()

        let inserted = highlighter.update(with: ["a", "b"])

        XCTAssertTrue(inserted.isEmpty)
        XCTAssertFalse(highlighter.isHighlighted("a"))
    }

    func testSubsequentSnapshotHighlightsOnlyNewRecordIDs() {
        var highlighter = RecentRecordHighlighter()
        _ = highlighter.update(with: ["a", "b"])

        let inserted = highlighter.update(with: ["c", "a", "b"])

        XCTAssertEqual(inserted, ["c"])
        XCTAssertTrue(highlighter.isHighlighted("c"))
        XCTAssertFalse(highlighter.isHighlighted("a"))
    }

    func testClearRemovesHighlightForRecordID() {
        var highlighter = RecentRecordHighlighter()
        _ = highlighter.update(with: ["a"])
        _ = highlighter.update(with: ["b", "a"])

        highlighter.clear("b")

        XCTAssertFalse(highlighter.isHighlighted("b"))
    }
}
