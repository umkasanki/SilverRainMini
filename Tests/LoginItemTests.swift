import ServiceManagement
import Testing
@testable import SilverRainMini

/// SPEC FR-10, PLAN 8.4: the switch shows what the system says.
@MainActor
struct LoginItemTests {
    private final class FakeService: LoginItemService {
        var status: SMAppService.Status = .notRegistered
        var failNext = false
        private(set) var calls: [String] = []

        func register() throws {
            calls.append("register")
            if failNext { throw CocoaError(.featureUnsupported) }
            status = .enabled
        }

        func unregister() throws {
            calls.append("unregister")
            if failNext { throw CocoaError(.featureUnsupported) }
            status = .notRegistered
        }
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
        #expect(LoginItem(service: service).status == shown)
    }

    @Test func waitingForApprovalStillReadsAsOn() {
        let service = FakeService()
        service.status = .requiresApproval
        #expect(LoginItem(service: service).isOn)
    }

    @Test func switchingOnAndOffRegistersAndUnregisters() {
        let service = FakeService()
        let item = LoginItem(service: service)
        item.setOn(true)
        #expect(item.status == .on)
        item.setOn(false)
        #expect(item.status == .off)
        #expect(service.calls == ["register", "unregister"])
    }

    @Test func aChangeMadeInSystemSettingsShowsOnRefresh() {
        let service = FakeService()
        let item = LoginItem(service: service)
        item.setOn(true)
        service.status = .notRegistered
        item.refresh()
        #expect(!item.isOn)
    }

    @Test func aFailureIsExplainedAndTheSwitchStaysTrue() {
        let service = FakeService()
        service.failNext = true
        let item = LoginItem(service: service)
        item.setOn(true)
        #expect(item.status == .off)
        #expect(item.problem == "Не удалось включить автозагрузку")
        service.failNext = false
        item.setOn(true)
        #expect(item.problem == nil)
        #expect(item.status == .on)
    }
}
