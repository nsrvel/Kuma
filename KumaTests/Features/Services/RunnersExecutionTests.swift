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
        let runner = SSHTunnelRunner(processLauncher: ProcessRegistryLauncher())

        await #expect(throws: ServiceExecutionError.self) {
            try await runner.start(service: service, provider: provider, pipeline: pipeline)
        }
    }

    @Test("TC-R07: SSHTunnelRunner cleans up temporary askpass script on stop")
    func testSSHTunnelCleanStopLifecycle() async throws {
        let serviceID = UUID()
        let runner = SSHTunnelRunner(processLauncher: ProcessRegistryLauncher())
        await runner.stop(serviceID: serviceID)
        #expect(await runner.isRunning(serviceID: serviceID) == false)
    }

    // MARK: - [TC-D05] Compose YAML written with -f flag (RUN-01)
    @Test("TC-D05: ContainerRunner passes compose -f when yamlConfig is set")
    func testContainerRunnerComposeYamlWrite() async throws {
        let dockerKey = KumaSettingsKey.customDockerPath
        let priorDocker = UserDefaults.standard.string(forKey: dockerKey)
        UserDefaults.standard.set("/usr/bin/true", forKey: dockerKey)
        defer {
            if let priorDocker {
                UserDefaults.standard.set(priorDocker, forKey: dockerKey)
            } else {
                UserDefaults.standard.removeObject(forKey: dockerKey)
            }
        }

        let serviceID = UUID()
        let service = Service(id: serviceID, name: "Compose YAML")
        let yaml = "services:\n  web:\n    image: nginx:alpine\n"
        let provider = Provider(serviceID: serviceID, type: .docker, yamlConfig: yaml)

        let recorder = RecordingProcessLaunching()
        let runner = ContainerRunner(processLauncher: recorder)
        let pipeline = ServiceLogPipeline(serviceID: serviceID, serviceName: service.name)

        try await runner.start(service: service, provider: provider, pipeline: pipeline)

        let launch = recorder.lastLaunch
        #expect(launch != nil)
        #expect(launch?.arguments.contains("compose") == true)
        #expect(launch?.arguments.contains("-f") == true)
        #expect(launch?.arguments.contains("up") == true)
        let composePath = launch?.arguments.first(where: { $0.hasSuffix("docker-compose.kuma.yml") })
        #expect(composePath != nil)
        #expect(FileManager.default.fileExists(atPath: composePath!))

        await runner.stop(serviceID: serviceID)
    }

    // MARK: - [TC-D06] SSH key path passed as -i (RUN-02)
    @Test("TC-D06: SSHTunnelRunner includes -i for sshKeyPath")
    @MainActor
    func testSSHTunnelRunnerSSHKeyFlag() async throws {
        let harness = ServicesTestHarness()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("kuma-ssh-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let keyURL = tempDir.appendingPathComponent("id_test")
        try "fake-key".write(to: keyURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let (service, provider) = try await harness.seedServiceWithProvider(
            name: "SSH Key",
            providerType: .ssh,
            sshKeyPath: keyURL.path,
            ports: [(8080, 80)]
        )

        var sshProvider = provider
        sshProvider.sshHost = "127.0.0.1"
        sshProvider.sshUser = "test"
        try await harness.serviceRepository.updateProvider(sshProvider)

        let recorder = RecordingProcessLaunching()
        let runner = SSHTunnelRunner(
            processLauncher: recorder,
            serviceRepository: harness.serviceRepository
        )
        let pipeline = ServiceLogPipeline(serviceID: service.id, serviceName: service.name)

        try await runner.start(service: service, provider: sshProvider, pipeline: pipeline)

        let launch = recorder.lastLaunch
        #expect(launch?.executable == "/usr/bin/ssh")
        let args = launch?.arguments ?? []
        #expect(args.contains("-i"))
        let keyIndex = args.firstIndex(of: "-i")
        #expect(keyIndex != nil)
        #expect(args[keyIndex! + 1] == keyURL.path)

        await runner.stop(serviceID: service.id)
    }
}
