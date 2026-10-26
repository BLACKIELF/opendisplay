import XCTest

final class ReceiverPanelGeometryTests: XCTestCase {
    func testOpeningAndClosingWithoutRotatingChangesAnnouncedPanel() throws {
        let outer = try XCTUnwrap(ReceiverPanelGeometry.make(
            pointsWide: 466, pointsHigh: 678, nativeScale: 3,
            maximumFramesPerSecond: 120))
        let inner = try XCTUnwrap(ReceiverPanelGeometry.make(
            pointsWide: 626, pointsHigh: 890, nativeScale: 3,
            maximumFramesPerSecond: 120))
        let closedAgain = try XCTUnwrap(ReceiverPanelGeometry.make(
            pointsWide: 466, pointsHigh: 678, nativeScale: 3,
            maximumFramesPerSecond: 120))

        XCTAssertEqual(outer.pixelsWide, 1_398)
        XCTAssertEqual(outer.pixelsHigh, 2_034)
        XCTAssertEqual(inner.pixelsWide, 1_878)
        XCTAssertEqual(inner.pixelsHigh, 2_670)
        XCTAssertLessThan(outer.pixelsWide, outer.pixelsHigh)
        XCTAssertLessThan(inner.pixelsWide, inner.pixelsHigh)
        XCTAssertNotEqual(outer, inner)
        XCTAssertEqual(closedAgain, outer)
    }

    func testRotationSwapsCurrentWindowAxesWithoutChangingScale() throws {
        let portrait = try XCTUnwrap(ReceiverPanelGeometry.make(
            pointsWide: 626, pointsHigh: 890, nativeScale: 3,
            maximumFramesPerSecond: 120))
        let landscape = try XCTUnwrap(ReceiverPanelGeometry.make(
            pointsWide: 890, pointsHigh: 626, nativeScale: 3,
            maximumFramesPerSecond: 120))
        XCTAssertEqual(landscape.pixelsWide, portrait.pixelsHigh)
        XCTAssertEqual(landscape.pixelsHigh, portrait.pixelsWide)
        XCTAssertEqual(landscape.scale, portrait.scale)
        XCTAssertEqual(landscape.maximumFramesPerSecond, portrait.maximumFramesPerSecond)
        XCTAssertNotEqual(landscape, portrait)
    }

    func testOrdinaryDevicesAndSplitWindowsUseTheirActualDrawableSize() throws {
        let layouts: [(Double, Double, Double, Int, Int)] = [
            (393, 852, 3, 1_179, 2_556),       // ordinary iPhone portrait
            (1_194, 834, 2, 2_388, 1_668),    // full iPad window
            (600, 834, 2, 1_200, 1_668),      // narrower window, same iPad scale
            (786.5, 512.25, 2, 1_573, 1_025), // arbitrary resized window
        ]
        for (width, height, scale, pixelsWide, pixelsHigh) in layouts {
            let panel = try XCTUnwrap(ReceiverPanelGeometry.make(
                pointsWide: width, pointsHigh: height, nativeScale: scale,
                maximumFramesPerSecond: 60))
            XCTAssertEqual(panel.pixelsWide, pixelsWide)
            XCTAssertEqual(panel.pixelsHigh, pixelsHigh)
            XCTAssertEqual(panel.scale, scale)
        }
    }

    func testFractionalNativeScaleRetainsPhysicalRasterAndWindowProportion() throws {
        let scale = 1_080.0 / 414.0
        let full = try XCTUnwrap(ReceiverPanelGeometry.make(
            pointsWide: 414, pointsHigh: 736, nativeScale: scale,
            maximumFramesPerSecond: 60))
        let halfWidth = try XCTUnwrap(ReceiverPanelGeometry.make(
            pointsWide: 207, pointsHigh: 736, nativeScale: scale,
            maximumFramesPerSecond: 60))
        XCTAssertEqual(full.pixelsWide, 1_080)
        XCTAssertEqual(full.pixelsHigh, 1_920)
        XCTAssertEqual(halfWidth.pixelsWide, 540)
        XCTAssertEqual(halfWidth.pixelsHigh, full.pixelsHigh)
        XCTAssertEqual(full.scale, scale)
    }

    func testFullScreenDisplayZoomUsesExactNativeRasterInEitherOrientation() throws {
        // A zoomed Plus phone has 667 points at 2.88 nativeScale, which
        // rounds to 1921 rather than the physical panel's 1920 pixels.
        for landscape in [false, true] {
            let points = landscape ? CGSize(width: 667, height: 375)
                                   : CGSize(width: 375, height: 667)
            let panel = try XCTUnwrap(ReceiverPanelGeometry.make(
                pointsWide: Double(points.width), pointsHigh: Double(points.height),
                nativeScale: 2.88, maximumFramesPerSecond: 60,
                screenSize: points, nativePixelSize: CGSize(width: 1080, height: 1920)))
            XCTAssertEqual(panel.pixelsWide, landscape ? 1920 : 1080)
            XCTAssertEqual(panel.pixelsHigh, landscape ? 1080 : 1920)
            XCTAssertEqual(panel.scale, 2.88)
        }
    }

    func testResizedWindowDoesNotAnnounceTheWholeNativePanel() throws {
        let panel = try XCTUnwrap(ReceiverPanelGeometry.make(
            pointsWide: 187.5, pointsHigh: 667, nativeScale: 2.88,
            maximumFramesPerSecond: 60,
            screenSize: CGSize(width: 375, height: 667),
            nativePixelSize: CGSize(width: 1080, height: 1920)))
        XCTAssertEqual(panel.pixelsWide, 540)
        XCTAssertEqual(panel.pixelsHigh, 1921)
    }

    func testInvalidFullScreenNativeRasterIsRejected() {
        for invalid in [0.0, -1.0, 3.0, Double.nan, Double.infinity, Double(Int.max)] {
            XCTAssertNil(ReceiverPanelGeometry.make(
                pointsWide: 375, pointsHigh: 667, nativeScale: 2.88,
                maximumFramesPerSecond: 60,
                screenSize: CGSize(width: 375, height: 667),
                nativePixelSize: CGSize(width: invalid, height: 1920)))
        }
    }

    func testInvalidIntermediateLayoutCannotReplaceAValidPanel() {
        for invalid in [0.0, -1.0, Double.nan, Double.infinity, -Double.infinity] {
            XCTAssertNil(ReceiverPanelGeometry.make(
                pointsWide: invalid, pointsHigh: 890, nativeScale: 3,
                maximumFramesPerSecond: 120))
            XCTAssertNil(ReceiverPanelGeometry.make(
                pointsWide: 626, pointsHigh: invalid, nativeScale: 3,
                maximumFramesPerSecond: 120))
            XCTAssertNil(ReceiverPanelGeometry.make(
                pointsWide: 626, pointsHigh: 890, nativeScale: invalid,
                maximumFramesPerSecond: 120))
        }
        XCTAssertNil(ReceiverPanelGeometry.make(
            pointsWide: 1, pointsHigh: 890, nativeScale: 3,
            maximumFramesPerSecond: 120))
        XCTAssertNil(ReceiverPanelGeometry.make(
            pointsWide: 626, pointsHigh: 1, nativeScale: 3,
            maximumFramesPerSecond: 120))
    }

    func testOverflowingLayoutIsRejectedBeforeIntegerConversion() {
        let overflow = Double.greatestFiniteMagnitude
        XCTAssertNil(ReceiverPanelGeometry.make(
            pointsWide: overflow, pointsHigh: 890, nativeScale: 3,
            maximumFramesPerSecond: 120))
        XCTAssertNil(ReceiverPanelGeometry.make(
            pointsWide: 626, pointsHigh: overflow, nativeScale: 3,
            maximumFramesPerSecond: 120))
        XCTAssertNil(ReceiverPanelGeometry.make(
            pointsWide: Double(Int.max), pointsHigh: 890, nativeScale: 1,
            maximumFramesPerSecond: 120))
        XCTAssertNil(ReceiverPanelGeometry.make(
            pointsWide: 626, pointsHigh: Double(Int.max), nativeScale: 1,
            maximumFramesPerSecond: 120))
    }

    func testRefreshRateChangeIsPartOfPanelState() throws {
        let standard = try XCTUnwrap(ReceiverPanelGeometry.make(
            pointsWide: 626, pointsHigh: 890, nativeScale: 3,
            maximumFramesPerSecond: 60))
        let highRefresh = try XCTUnwrap(ReceiverPanelGeometry.make(
            pointsWide: 626, pointsHigh: 890, nativeScale: 3,
            maximumFramesPerSecond: 120))
        XCTAssertNotEqual(standard, highRefresh)
        XCTAssertEqual(highRefresh.maximumFramesPerSecond, 120)
        for invalid in [0, -1] {
            XCTAssertNil(ReceiverPanelGeometry.make(
                pointsWide: 626, pointsHigh: 890, nativeScale: 3,
                maximumFramesPerSecond: invalid))
        }
    }
}
