import CoreGraphics
import Testing
@testable import SilverRainMini

/// NFR-4: every level is one click away, and the fill ends where the click landed.
@MainActor
struct VolumeSliderTests {
    private let width: CGFloat = 272
    private var zone: CGFloat { VolumeSlider.speakerZone }

    @Test func theScaleStartsRightOfTheSpeaker() {
        #expect(VolumeSlider.volume(atX: zone, width: width) == 0)
        #expect(VolumeSlider.volume(atX: width, width: width) == 1)
    }

    @Test(arguments: [0.02, 0.05, 0.08, 0.5, 0.97])
    func lowLevelsAreReachableByAClick(level: Double) {
        let x = zone + CGFloat(level) * (width - zone)
        #expect(abs(VolumeSlider.volume(atX: x, width: width) - level) < 0.0001)
    }

    @Test(arguments: [0.02, 0.4, 1.0])
    func theFillEndsWhereTheClickLanded(level: Double) {
        let x = zone + CGFloat(level) * (width - zone)
        #expect(abs(VolumeSlider.fillWidth(volume: VolumeSlider.volume(atX: x, width: width), width: width) - x) < 0.001)
    }

    @Test func silenceHasNoFill() {
        #expect(VolumeSlider.fillWidth(volume: 0, width: width) == 0)
    }

    @Test(arguments: [-40.0, 0, 500])
    func outsideTheTrackStaysInRange(x: CGFloat) {
        let level = VolumeSlider.volume(atX: x, width: width)
        #expect(level >= 0 && level <= 1)
    }
}
