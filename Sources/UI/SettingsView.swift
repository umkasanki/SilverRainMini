import SwiftUI

/// The Settings window. In step S1 it only proves that the window opens;
/// the controls arrive in step S6.
struct SettingsView: View {
    var body: some View {
        Form {
            LabeledContent("Версия", value: Self.version)
        }
        .formStyle(.grouped)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
