import SwiftUI

/// The glass panel under the menu bar icon (SPEC FR-6, the approved mockup):
/// two cards and a small "Свернуть" pill. The cards take their colour from
/// whatever is behind them; no colour is ever set on them. What they are made of
/// is chosen in Settings (`PanelSurface`).
struct PanelView: View {
    let appState: AppState
    let collapse: () -> Void

    @AppStorage(SettingsKey.panelSurface) private var surface = PanelSurface.default

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
                    .panelSurface(surface, in: .rect(cornerRadius: 20))

                    soundCard
                        .panelSurface(surface, in: .rect(cornerRadius: 20))
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
            .panelSurface(surface, in: .capsule)
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
                setVolume: { appState.setVolume($0, persist: $1) },
                adjustVolume: { appState.adjustVolume(by: $0) },
                toggleMute: appState.toggleMute
            )
        }
        .padding(.top, 11)
        .padding(.horizontal, 14)
        .padding(.bottom, 13)
    }
}
