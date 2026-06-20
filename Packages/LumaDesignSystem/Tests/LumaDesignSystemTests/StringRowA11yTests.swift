import Testing
@testable import LumaDesignSystem

@Suite("StringRow VoiceOver label conveys state")
struct StringRowA11yTests {
    @Test("locked (in-tune) state is announced, not color-only")
    func lockedAnnounced() {
        let label = StringCell.a11yLabel(idx: 6, note: "E", octave: 2, active: true, locked: true)
        #expect(label.contains("E2"))
        #expect(label.localizedCaseInsensitiveContains("in tune"))
    }

    @Test("plain string announces only its identity")
    func plain() {
        let label = StringCell.a11yLabel(idx: 6, note: "E", octave: 2, active: false, locked: false)
        #expect(label.contains("String 6"))
        #expect(!label.localizedCaseInsensitiveContains("in tune"))
    }
}
