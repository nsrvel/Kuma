import Foundation
import Testing
@testable import Kuma

@Suite("Feature 06 - Category D: Runtime/Process State Integration", .serialized)
@MainActor
struct ServicesRuntimeAndExecutionTests {

    // MARK: - ServiceStateNotification parsing
    @Test("TC-D07: ServiceStateNotification preserves PID when notification omits pid")
    func testServiceStateNotificationPreservesPID() {
        let existing = ServiceExecutionState.running(pid: 4242)
        let userInfo: [String: Any] = [ServiceStateNotification.stateKey: ServiceState.running]
        let parsed = ServiceStateNotification.executionState(from: userInfo, existing: existing)
        #expect(parsed == .running(pid: 4242))
    }

    @Test("TC-D08: ServiceStateNotification uses exitCode from userInfo")
    func testServiceStateNotificationExitCode() {
        let userInfo: [String: Any] = [
            ServiceStateNotification.stateKey: ServiceState.crashed,
            ServiceStateNotification.exitCodeKey: Int32(42)
        ]
        let parsed = ServiceStateNotification.executionState(from: userInfo, existing: .idle)
        #expect(parsed == .crashed(exitCode: 42))
    }

    // MARK: - [TC-D04] Batch Process Status Lookup
    @Test("TC-D04: ProcessRegistry.runningStates returns execution states in single call")
    func testBatchProcessStatusLookup() async {
        let registry = ProcessRegistry.shared
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        let states = await registry.runningStates(for: [id1, id2, id3])
        #expect(states.count == 3)
        #expect(states[id1] == .idle)
        #expect(states[id2] == .idle)
        #expect(states[id3] == .idle)
    }

    // MARK: - [TC-D03] ServiceStateStore Batch Refresh
    @Test("TC-D03: ServiceStateStore batch refresh integrates with runningStates")
    func testServiceStateStoreBatchRefresh() async {
        let store = ServiceStateStore()
        let id1 = UUID()
        let id2 = UUID()

        await store.refreshProcessStates(for: [id1, id2])
        #expect(store.state(for: id1) == .idle)
        #expect(store.state(for: id2) == .idle)

        store.setExecutionState(.starting, for: id1)
        // Background refresh should not clobber in-flight starting state
        await store.refreshProcessStates(for: [id1])
        #expect(store.state(for: id1) == .starting)
    }

    // MARK: - [TC-D05] ProcessRegistry Launch and Graceful Stop
    @Test("TC-D05: ProcessRegistry launches process and stops gracefully")
    func testProcessRegistryLaunchAndGracefulStop() async throws {
        let registry = ProcessRegistry.shared
        let serviceID = UUID()

        // Launch a sleep child process
        let pid = try await registry.launch(
            serviceID: serviceID,
            executable: "/bin/sleep",
            arguments: ["10"]
        )

        #expect(pid > 0)
        let isRunningBefore = await registry.isRunning(serviceID: serviceID)
        #expect(isRunningBefore == true)

        let snapshot = await registry.getSnapshot(serviceID: serviceID)
        #expect(snapshot != nil)
        #expect(snapshot?.pid == pid)

        // Stop gracefully
        await registry.stop(serviceID: serviceID)

        let isRunningAfter = await registry.isRunning(serviceID: serviceID)
        #expect(isRunningAfter == false)
    }

    // MARK: - [TC-D06] ProcessRegistry Output Capture
    @Test("TC-D06: ProcessRegistry captures stdout correctly")
    func testProcessRegistryCapturesStdout() async throws {
        let registry = ProcessRegistry.shared
        let serviceID = UUID()

        let captured = LockIsolated<[String]>([])

        _ = try await registry.launch(
            serviceID: serviceID,
            executable: "/bin/echo",
            arguments: ["hello-kuma-runtime"],
            onOutput: { text in
                captured.withValue { $0.append(text) }
            }
        )

        // Wait brief moment for echo process to exit and flush pipe
        try await Task.sleep(nanoseconds: 300_000_000)

        let outputs = captured.value
        #expect(outputs.joined().contains("hello-kuma-runtime"))
    }

    // MARK: - [TC-D07] Apply Runtime Diff Performance & Version Stability
    @Test("TC-D07: execution state updates without bumping filterVersion when status filters are inactive")
    func testExecutionStateFilterVersionStability() async {
        let store = ServiceStateStore()
        let deckVM = ServicesDeckViewModel(stateStore: store)
        let sID = UUID()

        let initialVersion = deckVM.filterVersion
        store.setExecutionState(.running(pid: 0), for: sID)
        deckVM.notifyExecutionStatesChanged()

        #expect(deckVM.runtime(for: sID).status == .running)
        #expect(deckVM.filterVersion == initialVersion)

        deckVM.selectedStatuses = [.running]
        let versionWithFilter = deckVM.filterVersion
        #expect(versionWithFilter > initialVersion)

        store.setExecutionState(.idle, for: sID)
        deckVM.notifyExecutionStatesChanged()
        #expect(deckVM.filterVersion > versionWithFilter)
    }
}

private final class LockIsolated<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Value

    init(_ value: Value) {
        self._value = value
    }

    var value: Value {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func withValue<R>(_ body: (inout Value) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&_value)
    }
}
