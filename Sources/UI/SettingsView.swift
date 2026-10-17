import SwiftUI

/// The Settings window (SPEC FR-10): a grouped form, so it looks like System
/// Settings. The stream and start-up controls arrive with the rest of step S6.
struct SettingsView: View {
    @AppStorage(SettingsKey.panelSurface) private var surface = PanelSurface.default

    var body: some View {
        Form {
            Section {
                Picker("Материал панели", selection: $surface) {
                    ForEach(PanelSurface.allCases) { surface in
                        Text(surface.title).tag(surface)
                    }
                }
            }
            Section {
                LabeledContent("Версия", value: Self.version)
            }
        }
        .formStyle(.grouped)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
