import Foundation
import Testing
@testable import Kuma

@Suite("Feature 06 - Category D: Runtime/Process State Integration", .serialized)
@MainActor
struct ServicesRuntimeAndExecutionTests {

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
    @Test("TC-D07: applyRuntimeDiff updates state without bumping filterVersion when status filters are inactive")
    func testApplyRuntimeDiffPerformance() async {
        let deckVM = ServicesDeckViewModel()
        let sID = UUID()

        let initialVersion = deckVM.filterVersion
        deckVM.applyRuntimeDiff([sID: ServiceRuntimeState(status: .running, isLoading: false)])

        #expect(deckVM.runtimeStates[sID]?.status == .running)
        // With no status filter or sort-by-status active, filterVersion should remain unchanged
        #expect(deckVM.filterVersion == initialVersion)

        // Now activate a status filter
        deckVM.selectedStatuses = [.running]
        let versionWithFilter = deckVM.filterVersion
        #expect(versionWithFilter > initialVersion)

        // Diffing status now SHOULD bump version and recompute
        deckVM.applyRuntimeDiff([sID: ServiceRuntimeState(status: .stopped, isLoading: false)])
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
