import Testing
@testable import SilverRainMini

/// SPEC FR-6, FR-10: the panel's surface, chosen in Settings.
struct PanelSurfaceTests {
    @Test func theUltraThinMaterialIsTheDefault() {
        #expect(PanelSurface.default == .ultraThinMaterial)
    }

    @Test func everyOptionHasItsOwnName() {
        let titles = PanelSurface.allCases.map(\.title)
        #expect(Set(titles).count == titles.count)
        #expect(titles.allSatisfy { !$0.isEmpty })
    }

    @Test func theSavedValueSurvivesARename() {
        // The raw values are what UserDefaults keeps; renaming a case must not lose a choice.
        #expect(PanelSurface(rawValue: "ultraThinMaterial") == .ultraThinMaterial)
        #expect(PanelSurface(rawValue: "clearGlass") == .clearGlass)
    }
}
