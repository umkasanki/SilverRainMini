#if DEBUG
import AppKit

/// Draws every look of the menu bar icon, light and dark, into PNG files, so the
/// icon can be checked without a screen: `--args -SRMDebugRenderIcons <folder>`.
@MainActor
enum DebugIconRenderer {
    static func render(to folder: URL) {
        let states: [(String, PlaybackState)] = [
            ("idle", .idle), ("connecting", .connecting), ("playing", .playing), ("error", .error(.notFound)),
        ]
        for (appearanceName, name) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            guard let appearance = NSAppearance(named: name) else { continue }
            for (stateName, state) in states {
                var png: Data?
                appearance.performAsCurrentDrawingAppearance { png = snapshot(of: state, dark: name == .darkAqua) }
                try? png?.write(to: folder.appending(path: "icon-\(stateName)-\(appearanceName).png"))
            }
        }
        let cover = StationArtwork.coverImage(side: 200)
        try? bitmap(cover.size) { cover.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1) }?
            .write(to: folder.appending(path: "cover.png"))
    }

    /// The icon at 4× on a strip coloured like the menu bar, as the menu bar would tint it.
    private static func snapshot(of state: PlaybackState, dark: Bool) -> Data? {
        let icon = MenuBarIcon.image(for: state)
        let size = NSSize(width: MenuBarIcon.size.width + 12, height: MenuBarIcon.size.height + 6)
        return bitmap(size, scale: 4) {
            (dark ? NSColor(white: 0.16, alpha: 1) : NSColor(white: 0.93, alpha: 1)).set()
            NSRect(origin: .zero, size: size).fill()
            let rect = NSRect(origin: NSPoint(x: 6, y: 3), size: MenuBarIcon.size)
            if icon.isTemplate {
                let tinted = NSImage(size: MenuBarIcon.size, flipped: false) { r in
                    icon.draw(in: r)
                    (dark ? NSColor.white : NSColor.black).withAlphaComponent(0.85).set()
                    r.fill(using: .sourceAtop)
                    return true
                }
                tinted.draw(in: rect)
            } else {
                icon.draw(in: rect)
            }
        }
    }

    private static func bitmap(_ size: NSSize, scale: CGFloat = 1, draw: () -> Void) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ) else { return nil }
        rep.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        draw()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}
#endif
