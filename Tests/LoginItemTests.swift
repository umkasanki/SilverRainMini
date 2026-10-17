import AppKit
import ServiceManagement
import Testing
@testable import SilverRainMini

/// SPEC FR-10, PLAN 8.4: the switch shows what the system says.
@MainActor
struct LoginItemTests {
    /// Called from a background task by `LoginItem`, hence the lock.
    private final class FakeService: LoginItemService, @unchecked Sendable {
        private let lock = NSLock()
        private var _status: SMAppService.Status = .notRegistered
        private var _failNext = false
        private var _calls: [String] = []

        var status: SMAppService.Status {
            get { lock.withLock { _status } }
            set { lock.withLock { _status = newValue } }
        }
        var failNext: Bool {
            get { lock.withLock { _failNext } }
            set { lock.withLock { _failNext = newValue } }
        }
        var calls: [String] { lock.withLock { _calls } }

        func register() throws {
            try lock.withLock {
                _calls.append("register")
                if _failNext { throw CocoaError(.featureUnsupported) }
                _status = .enabled
            }
        }

        func unregister() throws {
            try lock.withLock {
                _calls.append("unregister")
                if _failNext { throw CocoaError(.featureUnsupported) }
                _status = .notRegistered
            }
        }
    }

    private func item(_ service: FakeService) -> LoginItem {
        let item = LoginItem(service: service)
        item.refresh()
        return item
    }

    @Test(arguments: [
        (SMAppService.Status.notRegistered, LoginItem.Status.off),
        (.notFound, .off),
        (.enabled, .on),
        (.requiresApproval, .needsApproval),
    ])
    func showsWhatTheSystemSays(system: SMAppService.Status, shown: LoginItem.Status) {
        let service = FakeService()
        service.status = system
        #expect(item(service).status == shown)
    }

    @Test func waitingForApprovalStillReadsAsOn() {
        let service = FakeService()
        service.status = .requiresApproval
        #expect(item(service).isOn)
    }

    @Test func creatingOneDoesNotAskTheSystem() {
        let service = FakeService()
        service.status = .enabled
        #expect(LoginItem(service: service).status == .off)
    }

    @Test func switchingOnAndOffRegistersAndUnregisters() async {
        let service = FakeService()
        let item = item(service)
        await item.setOn(true)
        #expect(item.status == .on)
        await item.setOn(false)
        #expect(item.status == .off)
        #expect(service.calls == ["register", "unregister"])
        #expect(!item.isChanging)
    }

    @Test func aChangeMadeInSystemSettingsShowsWhenTheAppComesBack() {
        let service = FakeService()
        let item = item(service)
        service.status = .enabled
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: NSApp)
        #expect(item.isOn)
    }

    @Test func aFailureIsExplainedAndTheSwitchStaysTrue() async {
        let service = FakeService()
        service.failNext = true
        let item = item(service)
        await item.setOn(true)
        #expect(item.status == .off)
        #expect(item.problem == "Не удалось включить автозагрузку")
    }

    @Test func theErrorGoesOnceTheSystemShowsWhatWasAsked() async {
        let service = FakeService()
        service.failNext = true
        let item = item(service)
        await item.setOn(true)
        // The user turns it on in System Settings → Login Items instead.
        service.status = .enabled
        item.refresh()
        #expect(item.problem == nil)
        #expect(item.isOn)
    }
}
