import XCTest
@testable import LumaDesignSystem

/// Verifies the menu-bar caption logic (EXPERIENCE §8): quiet at rest, the note
/// once there's a live reading.
final class MenuBarStrobeTests: XCTestCase {

    func testQuietAtRest() {
        // Not listening → nothing in the bar, whatever the (stale) state/note.
        XCTAssertEqual(MenuBarStrobe.caption(note: "E", running: false, state: .flat), "")
        XCTAssertEqual(MenuBarStrobe.caption(note: "A", running: false, state: .tune), "")
        // Listening but no confident pitch (idle) → still quiet.
        XCTAssertEqual(MenuBarStrobe.caption(note: "E", running: true, state: .idle), "")
    }

    func testShowsNoteWhenLive() {
        XCTAssertEqual(MenuBarStrobe.caption(note: "A\u{266F}", running: true, state: .flat), "A\u{266F}")
        XCTAssertEqual(MenuBarStrobe.caption(note: "G", running: true, state: .sharp), "G")
        XCTAssertEqual(MenuBarStrobe.caption(note: "E", running: true, state: .tune), "E")
    }
}
