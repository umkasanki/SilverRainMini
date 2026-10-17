import SwiftUI

/// The glass panel under the menu bar icon (SPEC FR-6, the approved mockup):
/// two glass cards and a small "Свернуть" pill. The cards take their colour from
/// whatever is behind them; no colour is ever set on them. The glass is `.clear`:
/// side by side with Control Centre on the same wallpaper, `.regular` came out
/// dark and dense while Control Centre's tiles stay light (17.10.2026).
struct PanelView: View {
    let appState: AppState
    let collapse: () -> Void

    /// The width of the cards; the panel adds room for their shadow.
    static let width: CGFloat = 300

    var body: some View {
        VStack(spacing: 8) {
            GlassEffectContainer {
                VStack(spacing: 8) {
                    NowPlayingCard(
                        state: appState.player.state,
                        isOnFallback: appState.player.isOnFallback,
                        streamTitle: appState.streamTitle,
                        togglePlayback: appState.togglePlayback
                    )
                    .glassEffect(.clear, in: .rect(cornerRadius: 20))

                    soundCard
                        .glassEffect(.clear, in: .rect(cornerRadius: 20))
                }
            }

            Button(action: collapse) {
                Text("Свернуть")
                    .font(.system(size: 11.5))
                    .padding(.horizontal, 16)
                    .frame(height: 24)
                    .contentShape(.capsule)
            }
            .buttonStyle(.plain)
            .glassEffect(.clear.interactive(), in: .capsule)
            .padding(.top, 2)
        }
        .frame(width: Self.width)
        .padding(10)
    }

    private var soundCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Звук")
                .font(.system(size: 12, weight: .semibold))
            VolumeSlider(
                volume: appState.volume,
                isMuted: appState.isMuted,
                setVolume: appState.setVolume,
                toggleMute: appState.toggleMute
            )
        }
        .padding(.top, 11)
        .padding(.horizontal, 14)
        .padding(.bottom, 13)
    }
}
