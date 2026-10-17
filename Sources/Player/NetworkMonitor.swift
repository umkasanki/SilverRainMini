import Network
import os

/// What `AppState` needs to know about the network; tests stand in for it.
@MainActor
protocol NetworkMonitoring: AnyObject {
    var isAvailable: Bool { get }
    var onChange: ((Bool) -> Void)? { get set }
}

/// Tells when the Mac has a usable network path, so a reconnection
/// need not wait out its timer once the network is back (SPEC FR-5).
@MainActor
final class NetworkMonitor: NetworkMonitoring {
    private(set) var isAvailable = true
    var onChange: ((Bool) -> Void)?

    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isAvailable = path.status == .satisfied
            Task { @MainActor in self?.update(isAvailable) }
        }
        monitor.start(queue: .main)
    }

    private func update(_ isAvailable: Bool) {
        guard isAvailable != self.isAvailable else { return }
        self.isAvailable = isAvailable
        Logger.system.notice("Network \(isAvailable ? "available" : "lost", privacy: .public)")
        onChange?(isAvailable)
    }
}
