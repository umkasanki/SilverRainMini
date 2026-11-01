import AppKit
import SwiftUI

/// The station's logo on a plain white tile, like the app icon and the Now Playing
/// cover. It began translucent (PLAN 6.2, the approved mockup); the user asked for
/// solid white on 01.11.2026. The tile is not decoration: without it the dark blue
/// of the logo sinks in dark mode.
struct StationArtwork: View {
    private static let side: CGFloat = 46
    private static let cornerRadius: CGFloat = 11

    var body: some View {
        Image("StationLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 34, height: 33)
            .frame(width: Self.side, height: Self.side)
            .background(.white, in: .rect(cornerRadius: Self.cornerRadius))
            // The station's name stands right next to it.
            .accessibilityHidden(true)
    }

    /// The cover for Now Playing (SPEC FR-11): the logo on a light square.
    /// Callable from any thread: Now Playing asks for it off the main thread.
    /// 256 is sharp at the 128 pt Control Centre shows at most; the system keeps
    /// processed copies of the cover, and at 600 they cost 53 MB (NFR-1).
    nonisolated static func coverImage(side: CGFloat = 256) -> NSImage {
        NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSColor.white.set()
            rect.fill()
            let logo = NSImage(named: "StationLogo") ?? NSImage()
            let width = side * 0.72
            let height = logo.size.width > 0 ? width * logo.size.height / logo.size.width : width
            logo.draw(in: NSRect(x: (side - width) / 2, y: (side - height) / 2, width: width, height: height))
            return true
        }
    }
}
