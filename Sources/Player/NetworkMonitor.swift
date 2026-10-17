import Network
import os

/// Tells when the Mac has a usable network path, so a reconnection
/// need not wait out its timer once the network is back (SPEC FR-5).
@MainActor
final class NetworkMonitor {
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
