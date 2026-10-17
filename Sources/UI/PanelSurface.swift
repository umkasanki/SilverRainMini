import SwiftUI

/// What the panel's cards are made of (SPEC FR-6), chosen in Settings.
///
/// Two families: Liquid Glass, and the older frosted materials. The default is
/// the ultra-thin material: light and see-through over a coloured wallpaper like
/// the clear glass, yet it does not vanish over white the way the clear glass does
/// (all eight compared on screen, 17.10.2026).
enum PanelSurface: String, CaseIterable, Identifiable {
    case clearGlass
    case milkyClearGlass
    case glass
    case milkyGlass
    case ultraThinMaterial
    case thinMaterial
    case material
    case thickMaterial

    static let `default` = ultraThinMaterial

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clearGlass: "Стекло прозрачное"
        case .milkyClearGlass: "Стекло прозрачное, белёсое"
        case .glass: "Стекло обычное"
        case .milkyGlass: "Стекло обычное, белёсое"
        case .ultraThinMaterial: "Материал ультратонкий"
        case .thinMaterial: "Материал тонкий"
        case .material: "Материал обычный"
        case .thickMaterial: "Материал толстый"
        }
    }
}

extension View {
    /// Puts `surface` behind the view, clipped to `shape`. No colour of our own:
    /// every option is a system glass or material.
    func panelSurface(_ surface: PanelSurface, in shape: some Shape) -> some View {
        modifier(PanelSurfaceModifier(surface: surface, shape: shape))
    }
}

private struct PanelSurfaceModifier<S: Shape>: ViewModifier {
    let surface: PanelSurface
    let shape: S

    /// A breath of white that makes the glass milky.
    private static var milk: Color { .white.opacity(0.18) }

    func body(content: Content) -> some View {
        switch surface {
        case .clearGlass: content.glassEffect(.clear, in: shape)
        case .milkyClearGlass: content.glassEffect(.clear.tint(Self.milk), in: shape)
        case .glass: content.glassEffect(.regular, in: shape)
        case .milkyGlass: content.glassEffect(.regular.tint(Self.milk), in: shape)
        case .ultraThinMaterial: content.background(.ultraThinMaterial, in: shape)
        case .thinMaterial: content.background(.thinMaterial, in: shape)
        case .material: content.background(.regularMaterial, in: shape)
        case .thickMaterial: content.background(.thickMaterial, in: shape)
        }
    }
}
