import Testing
@testable import GlimbleCore

@Test func parsesPlainAndPrefixedVersions() {
    #expect(SemanticVersion("0.1.3") == SemanticVersion(0, 1, 3))
    #expect(SemanticVersion("v0.1.3") == SemanticVersion(0, 1, 3))
    #expect(SemanticVersion("V2.10.0") == SemanticVersion(2, 10, 0))
}

@Test func fillsMissingComponentsWithZero() {
    #expect(SemanticVersion("0.1") == SemanticVersion(0, 1, 0))
    #expect(SemanticVersion("3") == SemanticVersion(3, 0, 0))
}

@Test func ignoresPreReleaseSuffix() {
    #expect(SemanticVersion("0.1.3-beta.2") == SemanticVersion(0, 1, 3))
    #expect(SemanticVersion("1.2.0+build7") == SemanticVersion(1, 2, 0))
}

@Test func nonNumericIsNil() {
    #expect(SemanticVersion("dev") == nil)
    #expect(SemanticVersion("") == nil)
    #expect(SemanticVersion("v") == nil)
}

@Test func ordersByComponentSignificance() {
    #expect(SemanticVersion("0.1.3")! < SemanticVersion("0.1.4")!)
    #expect(SemanticVersion("0.1.9")! < SemanticVersion("0.2.0")!)
    #expect(SemanticVersion("0.9.9")! < SemanticVersion("1.0.0")!)
    #expect(SemanticVersion("0.2.0")! > SemanticVersion("0.1.9")!)
}

@Test func equalVersionsAreNotLess() {
    let a = SemanticVersion("0.1.3")!
    #expect(!(a < a))
    #expect(a == SemanticVersion("v0.1.3")!)
}
