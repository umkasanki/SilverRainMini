import Observation
import ServiceManagement
import os

/// What `LoginItem` needs from the system; tests stand in for it.
@MainActor
protocol LoginItemService: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

extension SMAppService: LoginItemService {}

/// «Запускать при входе в систему» (SPEC FR-10, PLAN 8.4). The system keeps this
/// setting, not UserDefaults, so the switch always shows what the system says —
/// including a change made in System Settings → Login Items.
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

    @ObservationIgnored private let service: any LoginItemService

    init(service: any LoginItemService = SMAppService.mainApp) {
        self.service = service
        refresh()
    }

    /// The switch reads «on» while macOS waits for approval too: the user did ask for it.
    var isOn: Bool { status != .off }

    /// Reads the state again; called whenever the Settings window shows the switch.
    func refresh() {
        status = switch service.status {
        case .enabled: .on
        case .requiresApproval: .needsApproval
        case .notRegistered, .notFound: .off
        @unknown default: .off
        }
    }

    func setOn(_ on: Bool) {
        problem = nil
        do {
            if on {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            Logger.system.error("Login item \(on ? "register" : "unregister", privacy: .public) failed: \(error, privacy: .public)")
            problem = on ? "Не удалось включить автозагрузку" : "Не удалось выключить автозагрузку"
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
