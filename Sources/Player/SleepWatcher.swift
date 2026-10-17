import AppKit
import os

/// Tells when the Mac is about to sleep and when it has woken (SPEC FR-5).
@MainActor
final class SleepWatcher {
    var onSleep: (() -> Void)?
    var onWake: (() -> Void)?

    private var observers: [any NSObjectProtocol] = []

    init() {
        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    Logger.system.notice("Going to sleep")
                    self?.onSleep?()
                }
            },
            center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    Logger.system.notice("Woke up")
                    self?.onWake?()
                }
            },
        ]
    }
}
