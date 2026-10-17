import SwiftUI

/// The glass panel under the menu bar icon. In step S1 it only proves the
/// glass and the layout; the real cards arrive in step S5.
struct PanelView: View {
    let collapse: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            GlassEffectContainer {
                VStack(spacing: 10) {
                    Text("Серебряный Дождь")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))

                    Text("Звук")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .glassEffect(.regular, in: .rect(cornerRadius: 20))
                }
            }

            Button("Свернуть", action: collapse)
                .buttonStyle(.glass)
                .controlSize(.small)
        }
        .padding(10)
        .frame(width: 300)
    }
}
