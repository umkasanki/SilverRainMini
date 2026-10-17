import AppKit
import Observation
import ServiceManagement
import os

/// What `LoginItem` needs from the system; tests stand in for it. Sendable, so the
/// slow calls into the system can run off the main thread.
protocol LoginItemService: Sendable {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

/// The app itself as a login item.
struct MainAppLoginItem: LoginItemService {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
}

/// «Запускать при входе в систему» (SPEC FR-10, PLAN 8.4). The system keeps this
/// setting, not UserDefaults, so the switch always shows what the system says —
/// including a change made in System Settings → Login Items, picked up whenever
/// the app becomes active again.
@MainActor
@Observable
final class LoginItem {
    enum Status: Equatable {
        case off
        case on
        /// Registered, but macOS wants the user to allow it in System Settings.
        case needsApproval
    }

    private(set) var status: Status = .off
    /// Why the last change did not take, in words for the Settings window.
    private(set) var problem: String?
    /// True while the system is being asked; the switch waits.
    private(set) var isChanging = false

    @ObservationIgnored private let service: any LoginItemService
    @ObservationIgnored private var lastRequest: Bool?
    @ObservationIgnored private var activationObserver: (any NSObjectProtocol)?

    /// Cheap on purpose: SwiftUI may build and drop several of these. The system
    /// is first asked in `refresh()`, when the switch is actually shown.
    init(service: any LoginItemService = MainAppLoginItem()) {
        self.service = service
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    isolated deinit {
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
    }

    /// The switch reads «on» while macOS waits for approval too: the user did ask for it.
    var isOn: Bool { status != .off }

    /// Reads the state again. An earlier error goes once the system shows what was asked for.
    func refresh() {
        status = switch service.status {
        case .enabled: .on
        case .requiresApproval: .needsApproval
        case .notRegistered, .notFound: .off
        @unknown default: .off
        }
        if let lastRequest, isOn == lastRequest {
            problem = nil
        }
    }

    /// Registering talks to a system daemon and can take a moment, so it runs off
    /// the main thread and the window stays responsive.
    func setOn(_ on: Bool) async {
        problem = nil
        lastRequest = on
        isChanging = true
        let service = self.service
        let succeeded = await Task.detached {
            do {
                if on { try service.register() } else { try service.unregister() }
                return true
            } catch {
                Logger.system.error("Login item \(on ? "register" : "unregister", privacy: .public) failed: \(error, privacy: .public)")
                return false
            }
        }.value
        isChanging = false
        if !succeeded {
            problem = on ? "Не удалось включить автозагрузку" : "Не удалось выключить автозагрузку"
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
