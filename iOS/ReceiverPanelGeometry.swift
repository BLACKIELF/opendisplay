import Foundation

/// The current receiver window in physical pixels. Kept independent of UIKit
/// so outer/inner display transitions and invalid layout values can be tested.
struct ReceiverPanelGeometry: Equatable {
    let pixelsWide: Int
    let pixelsHigh: Int
    let scale: Double
    let maximumFramesPerSecond: Int

    /// `screenSize` is the owning screen's bounds in points; `nativePixelSize`
    /// is its nativeBounds size. Full-screen windows retain that exact raster:
    /// Display Zoom can make points * nativeScale differ by a physical pixel.
    static func make(pointsWide: Double, pointsHigh: Double, nativeScale: Double,
                     maximumFramesPerSecond: Int, screenSize: CGSize? = nil,
                     nativePixelSize: CGSize? = nil) -> ReceiverPanelGeometry? {
        guard pointsWide.isFinite, pointsHigh.isFinite, nativeScale.isFinite,
              pointsWide > 0, pointsHigh > 0, nativeScale > 0,
              maximumFramesPerSecond > 0 else { return nil }
        let width: Double
        let height: Double
        if let screenSize, let nativePixelSize,
           pointsWide == Double(screenSize.width), pointsHigh == Double(screenSize.height) {
            let nativeWidth = Double(nativePixelSize.width)
            let nativeHeight = Double(nativePixelSize.height)
            guard nativeWidth.isFinite, nativeHeight.isFinite,
                  nativeWidth > 0, nativeHeight > 0 else { return nil }
            let longSide = max(nativeWidth, nativeHeight)
            let shortSide = min(nativeWidth, nativeHeight)
            width = (pointsWide > pointsHigh ? longSide : shortSide).rounded()
            height = (pointsWide > pointsHigh ? shortSide : longSide).rounded()
        } else {
            width = (pointsWide * nativeScale).rounded()
            height = (pointsHigh * nativeScale).rounded()
        }
        // Ignore zero-sized/intermediate invalid layouts instead of asking the
        // sender to destroy a working display. Check before converting to Int.
        guard width.isFinite, height.isFinite, width >= 4, height >= 4,
              width < Double(Int.max), height < Double(Int.max) else { return nil }
        return ReceiverPanelGeometry(pixelsWide: Int(width), pixelsHigh: Int(height),
                                     scale: nativeScale,
                                     maximumFramesPerSecond: maximumFramesPerSecond)
    }
}
