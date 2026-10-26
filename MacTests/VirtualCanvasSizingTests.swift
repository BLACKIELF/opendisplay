import XCTest

final class VirtualCanvasSizingTests: XCTestCase {
    func testSmallCanvasStartsAtRequestedSize() {
        let requested = VirtualCanvasSizing.requested(pixelsWide: 2_388, pixelsHigh: 1_668)!
        XCTAssertEqual(VirtualCanvasSizing.bootstrap(for: requested), requested)
    }

    func testLargeLandscapeCanvasBootstrapsAtSameAspect() {
        let requested = VirtualCanvasSizing.requested(pixelsWide: 4_096, pixelsHigh: 2_304)!
        XCTAssertEqual(VirtualCanvasSizing.bootstrap(for: requested),
                       VirtualCanvasSize(pointsWide: 1_600, pointsHigh: 900))
    }

    func testLargePortraitCanvasBootstrapsWithRotatedEnvelope() {
        let requested = VirtualCanvasSizing.requested(pixelsWide: 2_304, pixelsHigh: 4_096)!
        XCTAssertEqual(VirtualCanvasSizing.bootstrap(for: requested),
                       VirtualCanvasSize(pointsWide: 900, pointsHigh: 1_600))
    }

    func testInvalidCanvasIsRejected() {
        XCTAssertNil(VirtualCanvasSizing.requested(pixelsWide: 1, pixelsHigh: 1_080))
    }

    func testPlanReservesRequestedCapacityBeyondDefaultHeadroom() {
        let plan = VirtualCanvasSizing.plan(pixelsWide: 10_240, pixelsHigh: 4_320)!

        XCTAssertEqual(plan.bootstrap,
                       VirtualCanvasSize(pointsWide: 1_600, pointsHigh: 674))
        XCTAssertEqual(plan.descriptorMaxPixelsPerAxis, 10_240)
    }

    func testDuoInnerAndOuterPanelsKeepTheirDistinctShapesInBothOrientations() throws {
        // The panel dimensions are deliberately not multiples of four: the
        // virtual display rounds to even logical points at 2x scale.
        let layouts: [(PixelSize, PixelSize)] = [
            (PixelSize(width: 1_398, height: 2_034), PixelSize(width: 1_396, height: 2_032)),
            (PixelSize(width: 2_034, height: 1_398), PixelSize(width: 2_032, height: 1_396)),
            (PixelSize(width: 1_878, height: 2_670), PixelSize(width: 1_876, height: 2_668)),
            (PixelSize(width: 2_670, height: 1_878), PixelSize(width: 2_668, height: 1_876)),
        ]
        for (panel, expected) in layouts {
            let selected = VideoStreamConfiguration.canvasPixels(forReceiver: panel)
            XCTAssertEqual(selected, panel)
            let plan = try XCTUnwrap(VirtualCanvasSizing.plan(
                pixelsWide: selected.width, pixelsHigh: selected.height))
            let canvas = PixelSize(width: plan.requested.pixelsWide,
                                   height: plan.requested.pixelsHigh)
            XCTAssertEqual(canvas, expected)
            assertSameAspect(plan.bootstrap, as: panel)
            let stream = try VideoStreamConfiguration.makeForCanvas(
                canvas, panel: panel, quality: .best)
            XCTAssertEqual(stream.encodedSize, canvas)
            XCTAssertEqual(stream.framesPerSecond, 60)
        }
    }

    func testDuoAndExistingPanelsKeepAspectAcrossQualityPresets() throws {
        let panels = [
            PixelSize(width: 1_398, height: 2_034),
            PixelSize(width: 1_878, height: 2_670),
            PixelSize(width: 2_556, height: 1_179),
            PixelSize(width: 2_388, height: 1_668),
        ]
        for original in panels {
            for panel in [original, PixelSize(width: original.height, height: original.width)] {
                let plan = try XCTUnwrap(VirtualCanvasSizing.plan(
                    pixelsWide: panel.width, pixelsHigh: panel.height))
                let canvas = PixelSize(width: plan.requested.pixelsWide,
                                       height: plan.requested.pixelsHigh)
                for quality in StreamQuality.allCases {
                    let stream = try VideoStreamConfiguration.makeForCanvas(
                        canvas, panel: panel, quality: quality)
                    assertSameAspect(stream.encodedSize, as: panel)
                    XCTAssertLessThanOrEqual(stream.encodedSize.width, canvas.width)
                    XCTAssertLessThanOrEqual(stream.encodedSize.height, canvas.height)
                }
            }
        }
    }

    func testDuoCanvasRespectsLegacyAndModernDecodeLimitsWithoutStretching() throws {
        for original in [PixelSize(width: 1_398, height: 2_034),
                         PixelSize(width: 1_878, height: 2_670)] {
            for panel in [original, PixelSize(width: original.height, height: original.width)] {
                for useCapabilities in [false, true] {
                    let ceiling = PixelSize(width: 1_920, height: 1_080)
                    let caps = useCapabilities
                        ? [VideoCapability(codec: "h264", maxWidth: ceiling.width,
                                           maxHeight: ceiling.height, maxFrameRate: 30)]
                        : nil
                    let legacy = useCapabilities ? nil : ceiling
                    let selected = VideoStreamConfiguration.canvasPixels(
                        forReceiver: panel, legacyCeiling: legacy,
                        receiverCapabilities: caps)
                    let plan = try XCTUnwrap(VirtualCanvasSizing.plan(
                        pixelsWide: selected.width, pixelsHigh: selected.height))
                    let canvas = PixelSize(width: plan.requested.pixelsWide,
                                           height: plan.requested.pixelsHigh)
                    XCTAssertLessThanOrEqual(canvas.width, ceiling.width)
                    XCTAssertLessThanOrEqual(canvas.height, ceiling.height)
                    assertSameAspect(canvas, as: panel)
                    let stream = try VideoStreamConfiguration.makeForCanvas(
                        canvas, panel: panel, quality: .best,
                        legacyCeiling: legacy, receiverCapabilities: caps)
                    XCTAssertEqual(stream.encodedSize, canvas)
                    XCTAssertEqual(stream.framesPerSecond, useCapabilities ? 30 : 60)
                }
            }
        }
    }

    private func assertSameAspect(_ size: VirtualCanvasSize, as panel: PixelSize,
                                  file: StaticString = #filePath, line: UInt = #line) {
        assertSameAspect(PixelSize(width: size.pixelsWide, height: size.pixelsHigh),
                         as: panel, file: file, line: line)
    }

    private func assertSameAspect(_ size: PixelSize, as panel: PixelSize,
                                  file: StaticString = #filePath, line: UInt = #line) {
        // Measure on the short edge so a portrait orientation does not amplify
        // the same rounding loss. Allow only the few pixels lost by even-point
        // and even-pixel rounding, including a bootstrap/quality scaling pass.
        let panelShort = min(panel.width, panel.height)
        let panelLong = max(panel.width, panel.height)
        let sizeShort = min(size.width, size.height)
        let sizeLong = max(size.width, size.height)
        XCTAssertEqual(size.width > size.height, panel.width > panel.height,
                       file: file, line: line)
        let proportionalShort = Double(sizeLong) * Double(panelShort) / Double(panelLong)
        XCTAssertLessThanOrEqual(abs(proportionalShort - Double(sizeShort)), 6,
                                "\(size) changed the aspect of \(panel)", file: file, line: line)
    }
}

final class VirtualCanvasOneXTests: XCTestCase {
    func testOneXCanvasUsesPixelsAsPoints() {
        let requested = VirtualCanvasSizing.requested(pixelsWide: 2_560, pixelsHigh: 1_440, scale: 1)!
        XCTAssertEqual(requested, VirtualCanvasSize(pointsWide: 2_560, pointsHigh: 1_440, scale: 1))
        XCTAssertEqual(requested.pixelsWide, 2_560)
    }

    func testBootstrapEnvelopeIsInPixelsForEitherScale() {
        // 3200x1800 pixels: 1600x900 points at 2x, 3200x1800 points at 1x.
        let oneX = VirtualCanvasSizing.requested(pixelsWide: 3_840, pixelsHigh: 2_160, scale: 1)!
        XCTAssertEqual(VirtualCanvasSizing.bootstrap(for: oneX),
                       VirtualCanvasSize(pointsWide: 3_200, pointsHigh: 1_800, scale: 1))
    }
}
