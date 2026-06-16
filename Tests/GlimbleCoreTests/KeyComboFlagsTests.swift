import Testing
import CoreGraphics
@testable import GlimbleCore

@Test func mapsModifiersToCGEventFlags() {
    let combo = KeyCombo(keyCode: 0, modifiers: [.command, .shift])
    let flags = combo.cgEventFlags
    #expect(flags.contains(.maskCommand))
    #expect(flags.contains(.maskShift))
    #expect(!flags.contains(.maskControl))
    #expect(!flags.contains(.maskAlternate))
}

@Test func emptyModifiersAreEmptyFlags() {
    #expect(KeyCombo(keyCode: 36, modifiers: []).cgEventFlags.isEmpty)
}
