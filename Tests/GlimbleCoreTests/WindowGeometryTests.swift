import Testing
import CoreGraphics
@testable import GlimbleCore

// Single 1920x1080 display, menu bar 25px tall at top, no Dock:
// AppKit visibleFrame = origin (0,0), size 1920 x 1055.
private let vf = CGRect(x: 0, y: 0, width: 1920, height: 1055)

@Test func fillFillsVisibleFrame() {
    #expect(WindowGeometry.snapRect(.fill, in: vf) == vf)
}

@Test func maximizeFillsVisibleFrame() {
    #expect(WindowGeometry.snapRect(.maximize, in: vf) == vf)
}

@Test func leftHalf() {
    #expect(WindowGeometry.snapRect(.left, in: vf) == CGRect(x: 0, y: 0, width: 960, height: 1055))
}

@Test func rightHalf() {
    #expect(WindowGeometry.snapRect(.right, in: vf) == CGRect(x: 960, y: 0, width: 960, height: 1055))
}

@Test func topHalfIsHigherYInAppKit() {
    // AppKit bottom-left origin: the top half has the larger y.
    #expect(WindowGeometry.snapRect(.top, in: vf) == CGRect(x: 0, y: 527.5, width: 1920, height: 527.5))
}

@Test func bottomHalf() {
    #expect(WindowGeometry.snapRect(.bottom, in: vf) == CGRect(x: 0, y: 0, width: 1920, height: 527.5))
}

@Test func topLeftQuarter() {
    #expect(WindowGeometry.snapRect(.topLeft, in: vf) == CGRect(x: 0, y: 527.5, width: 960, height: 527.5))
}

@Test func bottomRightQuarter() {
    #expect(WindowGeometry.snapRect(.bottomRight, in: vf) == CGRect(x: 960, y: 0, width: 960, height: 527.5))
}

@Test func centerIsSixtyPercentCentered() {
    let r = WindowGeometry.snapRect(.center, in: vf)
    #expect(abs(r.width - 1152) < 0.001)   // 1920 * 0.6
    #expect(abs(r.height - 633) < 0.001)   // 1055 * 0.6
    #expect(abs(r.midX - vf.midX) < 0.001)
    #expect(abs(r.midY - vf.midY) < 0.001)
}

@Test func axFlipForLeftHalfSitsUnderMenuBar() {
    // Left-half AppKit rect on the primary display, primary is 1080 tall.
    let appKit = CGRect(x: 0, y: 0, width: 960, height: 1055)
    let origin = WindowGeometry.axOrigin(forAppKitRect: appKit, primaryHeight: 1080)
    // Top of window is 25px down (the menu-bar height): 1080 - 0 - 1055 = 25.
    #expect(origin == CGPoint(x: 0, y: 25))
}

@Test func axFlipGoesNegativeForDisplayAbovePrimary() {
    // A display stacked directly above the primary: AppKit origin.y = 1080.
    let appKit = CGRect(x: 0, y: 1080, width: 1920, height: 1080)
    let origin = WindowGeometry.axOrigin(forAppKitRect: appKit, primaryHeight: 1080)
    #expect(origin == CGPoint(x: 0, y: -1080))
}

@Test func axFlipPreservesX() {
    let appKit = CGRect(x: 960, y: 0, width: 960, height: 1055)
    let origin = WindowGeometry.axOrigin(forAppKitRect: appKit, primaryHeight: 1080)
    #expect(origin == CGPoint(x: 960, y: 25))
}
