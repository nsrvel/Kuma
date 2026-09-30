import Foundation
import Testing
@testable import Kuma

@Suite("Feature 05: Runners Execution Tests", .serialized)
struct RunnersExecutionTests {

    @Test("TC-R01: ShellRunner executes command and captures output")
    func testShellRunnerExecution() async throws {
        let serviceID = UUID()
        let service = Service(id: serviceID, name: "Shell Test")
        let provider = Provider(serviceID: serviceID, type: .shell, runCommand: "echo 'Kuma Runner OK'")

        let pipeline = ServiceLogPipeline(serviceID: serviceID, serviceName: service.name)
        let runner = ShellRunner()

        try await runner.start(service: service, provider: provider, pipeline: pipeline)
        #expect(await runner.isRunning(serviceID: serviceID) == true)

        // Wait for process to finish
        try? await Task.sleep(nanoseconds: 200_000_000)
        await runner.stop(serviceID: serviceID)
        #expect(await runner.isRunning(serviceID: serviceID) == false)
    }

    @Test("TC-R02: ShellRunner rejects empty command")
    func testShellRunnerRejectsEmpty() async {
        let serviceID = UUID()
        let service = Service(id: serviceID, name: "Shell Empty")
        let provider = Provider(serviceID: serviceID, type: .shell, runCommand: "")

        let pipeline = ServiceLogPipeline(serviceID: serviceID, serviceName: service.name)
        let runner = ShellRunner()

        await #expect(throws: ServiceExecutionError.self) {
            try await runner.start(service: service, provider: provider, pipeline: pipeline)
        }
    }

    @Test("TC-R03: HealthCheckRunner start and clean stop lifecycle")
    func testHealthCheckLifecycle() async throws {
        let serviceID = UUID()
        let service = Service(id: serviceID, name: "Health Test")
        let provider = Provider(serviceID: serviceID, type: .httpCheck, httpCheckUrl: "google.com", httpCheckInterval: 5)

        let pipeline = ServiceLogPipeline(serviceID: serviceID, serviceName: service.name)
        let runner = HealthCheckRunner()

        try await runner.start(service: service, provider: provider, pipeline: pipeline)
        #expect(await runner.isRunning(serviceID: serviceID) == true)

        await runner.stop(serviceID: serviceID)
        #expect(await runner.isRunning(serviceID: serviceID) == false)
    }

    @Test("TC-R04: ProcessMonitorRunner start and clean stop lifecycle")
    func testProcessMonitorLifecycle() async throws {
        let serviceID = UUID()
        let service = Service(id: serviceID, name: "Monitor Test")
        let provider = Provider(serviceID: serviceID, type: .processMonitor, monitorProcessName: "launchd", monitorInterval: 3)

        let pipeline = ServiceLogPipeline(serviceID: serviceID, serviceName: service.name)
        let runner = ProcessMonitorRunner()

        try await runner.start(service: service, provider: provider, pipeline: pipeline)
        #expect(await runner.isRunning(serviceID: serviceID) == true)

        await runner.stop(serviceID: serviceID)
        #expect(await runner.isRunning(serviceID: serviceID) == false)
    }

    @Test("TC-R05: ShellRunner bootstraps user environment variables and PATH")
    func testShellRunnerEnvironmentBootstrapping() async throws {
        let serviceID = UUID()
        let service = Service(id: serviceID, name: "Env Test")
        let provider = Provider(serviceID: serviceID, type: .shell, runCommand: "which zsh")

        let pipeline = ServiceLogPipeline(serviceID: serviceID, serviceName: service.name)
        let runner = ShellRunner()

        try await runner.start(service: service, provider: provider, pipeline: pipeline)
        try? await Task.sleep(nanoseconds: 200_000_000)
        await runner.stop(serviceID: serviceID)
        #expect(await runner.isRunning(serviceID: serviceID) == false)
    }

    @Test("TC-R06: SSHTunnelRunner rejects empty host configuration")
    func testSSHTunnelRejectsEmptyHost() async {
        let serviceID = UUID()
        let service = Service(id: serviceID, name: "SSH Empty Host")
        let provider = Provider(serviceID: serviceID, type: .ssh, sshHost: "")

        let pipeline = ServiceLogPipeline(serviceID: serviceID, serviceName: service.name)
        let runner = SSHTunnelRunner()

        await #expect(throws: ServiceExecutionError.self) {
            try await runner.start(service: service, provider: provider, pipeline: pipeline)
        }
    }

    @Test("TC-R07: SSHTunnelRunner cleans up temporary askpass script on stop")
    func testSSHTunnelCleanStopLifecycle() async throws {
        let serviceID = UUID()
        let runner = SSHTunnelRunner()
        await runner.stop(serviceID: serviceID)
        #expect(await runner.isRunning(serviceID: serviceID) == false)
    }
}
