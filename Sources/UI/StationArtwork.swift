import AppKit
import SwiftUI

/// The station's logo on a light, translucent tile (PLAN 6.2, the approved mockup).
/// The tile is not decoration: without it the dark blue of the logo sinks in dark mode.
struct StationArtwork: View {
    @Environment(\.colorScheme) private var colorScheme

    private static let side: CGFloat = 46
    private static let cornerRadius: CGFloat = 11

    var body: some View {
        let isDark = colorScheme == .dark
        Image("StationLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 34, height: 33)
            .frame(width: Self.side, height: Self.side)
            .background(.white.opacity(isDark ? 0.72 : 0.62), in: .rect(cornerRadius: Self.cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .strokeBorder(.white.opacity(isDark ? 0.35 : 0.65), lineWidth: 0.5)
            }
            // The station's name stands right next to it.
            .accessibilityHidden(true)
    }

    /// The cover for Now Playing (SPEC FR-11): the logo on a light square.
    static func coverImage(side: CGFloat = 600) -> NSImage {
        NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.white.set()
            rect.fill()
            let logo = NSImage(named: "StationLogo") ?? NSImage()
            let logoSide = side * 0.72
            logo.draw(in: NSRect(
                x: (side - logoSide) / 2, y: (side - logoSide * 270 / 276) / 2,
                width: logoSide, height: logoSide * 270 / 276
            ))
            return true
        }
    }
}
