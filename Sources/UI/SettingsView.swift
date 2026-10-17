import SwiftUI

/// The «Основные» pane of the Settings window (SPEC FR-10): a grouped form, so it
/// looks like System Settings. The login item arrives in step S7.
struct GeneralSettingsView: View {
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

        }
        .formStyle(.grouped)
        .settingsPane()
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
}

/// The Settings window: two panes. The window takes each pane's size, shows its
/// name as the title and reopens on the pane last seen (HIG, Settings).
///
/// The panes are switched by a segmented control rather than the toolbar the HIG
/// describes: the user wanted words only, and the settings toolbar keeps an empty
/// square above each word when the symbols are removed (seen on screen, 17.10.2026).
struct SettingsView: View {
    private enum Pane: String, CaseIterable {
        case general, about

        var title: String {
            switch self {
            case .general: "Основные"
            case .about: "О программе"
            }
        }
    }

    @AppStorage(SettingsKey.settingsPane) private var pane = Pane.general

    var body: some View {
        VStack(spacing: 0) {
            Picker("Раздел", selection: $pane) {
                ForEach(Pane.allCases, id: \.self) { pane in
                    Text(pane.title).tag(pane)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(.top, 14)

            switch pane {
            case .general: GeneralSettingsView()
            case .about: AboutView()
            }
        }
        .navigationTitle(pane.title)
    }
}

extension View {
    /// The common frame of a settings pane. A grouped form has no width of its own;
    /// this one fits the longest label and menu. The height follows the content,
    /// and so does the window, so there is nothing to scroll. The margins are wider
    /// than the form's own: at the default they looked cramped (17.10.2026).
    func settingsPane() -> some View {
        frame(width: 480)
            .contentMargins(.horizontal, 12, for: .scrollContent)
            .contentMargins(.vertical, 10, for: .scrollContent)
            .fixedSize(horizontal: false, vertical: true)
            .scrollDisabled(true)
    }
}
