import SwiftUI

/// The Settings window (SPEC FR-10): a grouped form, so it looks like System
/// Settings. The login item arrives in step S7.
struct SettingsView: View {
    @AppStorage(SettingsKey.playOnLaunch) private var playsOnLaunch = true
    @AppStorage(SettingsKey.streamID) private var streamID = StreamCatalog.bundled.defaultStream.id
    @AppStorage(SettingsKey.customURL) private var customURL = ""
    @AppStorage(SettingsKey.showQuality) private var showsQuality = false
    @AppStorage(SettingsKey.panelSurface) private var surface = PanelSurface.default

    /// The address as typed. It is saved on Return or «Проверить», not on every key:
    /// while the custom stream plays, each save switches to the new address.
    @State private var draftAddress = ""
    @State private var probeOutcome: StreamProbe.Outcome?
    @State private var isProbing = false

    private let catalog = StreamCatalog.bundled

    var body: some View {
        Form {
            Section {
                Toggle("Включать радио при запуске", isOn: $playsOnLaunch)
            }

            Section("Поток") {
                Picker("Поток", selection: $streamID) {
                    ForEach(catalog.streams) { stream in
                        Text(stream.title).tag(stream.id)
                    }
                    Divider()
                    Text("Свой адрес…").tag(StreamCatalog.customID)
                }
                if streamID == StreamCatalog.customID {
                    customAddress
                }
                Toggle("Показывать качество в панели", isOn: $showsQuality)
            }

            Section("Вид") {
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
        .onAppear { draftAddress = customURL }
    }

    private var customAddress: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                TextField("Адрес", text: $draftAddress, prompt: Text("https://…"))
                    .onSubmit(saveAddress)
                Button("Проверить") {
                    saveAddress()
                    probe()
                }
                .disabled(isProbing)
            }
            if isProbing {
                Text("Проверяю…").font(.callout).foregroundStyle(.secondary)
            } else if let probeOutcome {
                switch probeOutcome {
                case .stream(let description):
                    Label(description, systemImage: "checkmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                case .failure(let message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func saveAddress() {
        customURL = draftAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func probe() {
        isProbing = true
        probeOutcome = nil
        let address = draftAddress
        Task {
            let outcome = await StreamProbe().probe(address)
            probeOutcome = outcome
            isProbing = false
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
