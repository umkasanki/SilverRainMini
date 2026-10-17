import AppKit
import os

/// What `AppState` needs to know about sleep; tests stand in for it.
@MainActor
protocol SleepWatching: AnyObject {
    var onSleep: (() -> Void)? { get set }
    var onWake: (() -> Void)? { get set }
}

/// Tells when the Mac is about to sleep and when it has woken (SPEC FR-5).
@MainActor
final class SleepWatcher: SleepWatching {
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
