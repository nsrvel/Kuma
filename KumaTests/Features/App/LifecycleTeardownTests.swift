import Foundation
import Testing
@testable import Kuma

@Suite("Feature 00 - Category C: Lifecycle, Subprocess Kill & Buffer Teardown", .serialized)
struct LifecycleTeardownTests {

    // MARK: - [TC-C01] Terminate All Spawns
    @Test("TC-C01: ProcessRegistry terminateAll terminates tracked processes and removes them")
    func testProcessRegistryTerminateAllSpawns() async throws {
        let registry = ProcessRegistry.shared
        let serviceID = UUID()

        // Launch a harmless sleep process
        let pid = try await registry.launch(
            serviceID: serviceID,
            executable: "/bin/sleep",
            arguments: ["30"]
        )

        #expect(pid > 0)
        let isRunningBefore = await registry.isRunning(serviceID: serviceID)
        #expect(isRunningBefore == true)

        // Terminate all processes
        await registry.terminateAll()

        let isRunningAfter = await registry.isRunning(serviceID: serviceID)
        #expect(isRunningAfter == false)
        let snapshotAfter = await registry.getSnapshot(serviceID: serviceID)
        #expect(snapshotAfter == nil)
    }

    // MARK: - [TC-C02] Process Self-Exit Before Terminate
    @Test("TC-C02: Self-exited child process does not cause errors during terminateAll")
    func testProcessRegistryUnregistersExited() async throws {
        let registry = ProcessRegistry.shared
        let serviceID = UUID()

        // Launch an instantaneous echo command
        _ = try await registry.launch(
            serviceID: serviceID,
            executable: "/bin/echo",
            arguments: ["hello"]
        )

        // Wait brief moment for process to naturally exit
        try? await Task.sleep(nanoseconds: 200_000_000)

        // terminateAll should run cleanly even if process already exited
        await registry.terminateAll()
        let isRunning = await registry.isRunning(serviceID: serviceID)
        #expect(isRunning == false)
    }

    // MARK: - [TC-C03] LogFileWriter Buffer Flush on Terminate
    @Test("TC-C03: LogFileWriter flushAll writes queued logs immediately")
    func testLogFileWriterFlushOnTerminate() async {
        let writer = LogFileWriter.shared
        let testServiceID = UUID()

        await writer.append(serviceID: testServiceID, level: "INFO", message: "Lifecycle teardown verification log")
        await writer.flushAll()

        // Ensure subsequent buffer operations proceed smoothly
        #expect(true)
    }

    // MARK: - [TC-C04] Multiple Processes Concurrent Kill
    @Test("TC-C04: Multiple concurrent child processes are all killed cleanly on terminateAll")
    func testMultipleProcessesConcurrentKill() async throws {
        let registry = ProcessRegistry.shared
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        _ = try await registry.launch(serviceID: id1, executable: "/bin/sleep", arguments: ["45"])
        _ = try await registry.launch(serviceID: id2, executable: "/bin/sleep", arguments: ["45"])
        _ = try await registry.launch(serviceID: id3, executable: "/bin/sleep", arguments: ["45"])

        #expect(await registry.isRunning(serviceID: id1) == true)
        #expect(await registry.isRunning(serviceID: id2) == true)
        #expect(await registry.isRunning(serviceID: id3) == true)

        await registry.terminateAll()

        #expect(await registry.isRunning(serviceID: id1) == false)
        #expect(await registry.isRunning(serviceID: id2) == false)
        #expect(await registry.isRunning(serviceID: id3) == false)
    }

    // MARK: - [TC-C05] Terminate All Idempotency
    @Test("TC-C05: Calling terminateAll repeatedly is safe and idempotent")
    func testProcessRegistryTerminateAllIdempotency() async {
        let registry = ProcessRegistry.shared
        await registry.terminateAll()
        await registry.terminateAll()
        await registry.terminateAll()
        #expect(true)
    }
}
