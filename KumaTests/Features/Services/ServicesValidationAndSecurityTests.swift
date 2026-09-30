import Foundation
import Testing
import GRDB
@testable import Kuma

@Suite("Feature 06 - Category B: Services Validation, Crypto & Schema Security", .serialized)
@MainActor
struct ServicesValidationAndSecurityTests {

    // MARK: - [TC-B01] SSH Password Encrypted In Database
    @Test("TC-B01: SSH Password stored encrypted in SQLite and decrypted on fetch")
    func testSSHPasswordEncryptedInDatabase() async throws {
        let harness = ServicesTestHarness()
        let plainPassword = "SuperSecretSSHPassword123!"

        let (service, provider) = try await harness.seedServiceWithProvider(
            name: "SSH Server",
            providerType: .ssh,
            sshPassword: plainPassword
        )

        // 1. Verify raw value in SQLite column is NOT plaintext
        try await harness.databaseQueue.read { db in
            let row = try Row.fetchOne(db, sql: "SELECT sshPassword FROM provider WHERE id = ?", arguments: [provider.id.uuidString])
            let rawInDb: String? = row?["sshPassword"]
            #expect(rawInDb != nil)
            #expect(rawInDb != plainPassword, "Raw password in SQLite must NOT be stored in plaintext")
            #expect(rawInDb!.contains(":"), "Ciphertext should be formatted as nonce:tag:ciphertext")
        }

        // 2. Verify repository fetch decodes and decrypts back to plain text
        let fetchedProviders = try await harness.serviceRepository.fetchProviders(forService: service.id)
        #expect(fetchedProviders.count == 1)
        #expect(fetchedProviders.first?.sshPassword == plainPassword)
    }

    // MARK: - [TC-B02] Ngrok Auth Token Encrypted In Database
    @Test("TC-B02: Ngrok Auth Token stored encrypted in SQLite and decrypted on fetch")
    func testNgrokTokenEncryptedInDatabase() async throws {
        let harness = ServicesTestHarness()
        let plainToken = "2Bxx_SecretNgrokTokenXYZ999"

        let (service, provider) = try await harness.seedServiceWithProvider(
            name: "Public Webhook Tunnel",
            providerType: .tunnel,
            ngrokAuthToken: plainToken
        )

        // 1. Verify raw value in SQLite column is encrypted
        try await harness.databaseQueue.read { db in
            let row = try Row.fetchOne(db, sql: "SELECT ngrokAuthToken FROM provider WHERE id = ?", arguments: [provider.id.uuidString])
            let rawInDb: String? = row?["ngrokAuthToken"]
            #expect(rawInDb != nil)
            #expect(rawInDb != plainToken, "Raw token in SQLite must NOT be stored in plaintext")
            #expect(rawInDb!.contains(":"), "Ciphertext should be formatted as nonce:tag:ciphertext")
        }

        // 2. Verify repository fetch returns plain token
        let fetchedProviders = try await harness.serviceRepository.fetchProviders(forService: service.id)
        #expect(fetchedProviders.count == 1)
        #expect(fetchedProviders.first?.ngrokAuthToken == plainToken)
    }

    // MARK: - [TC-B03] Custom KubeConfig Path Persistence
    @Test("TC-B03: Custom KubeConfig Path persists in SQLite (Schema V4)")
    func testCustomKubeConfigPathPersistence() async throws {
        let harness = ServicesTestHarness()
        let customPath = "/Users/developer/.kube/staging-cluster.yaml"

        let (service, provider) = try await harness.seedServiceWithProvider(
            name: "Staging Cluster",
            providerType: .kubernetes,
            customKubeConfigPath: customPath
        )

        // 1. Verify raw column in SQLite exists and has custom path
        try await harness.databaseQueue.read { db in
            let row = try Row.fetchOne(db, sql: "SELECT customKubeConfigPath FROM provider WHERE id = ?", arguments: [provider.id.uuidString])
            let rawPath: String? = row?["customKubeConfigPath"]
            #expect(rawPath == customPath)
        }

        // 2. Verify fetch preserves custom path
        let fetchedProviders = try await harness.serviceRepository.fetchProviders(forService: service.id)
        #expect(fetchedProviders.count == 1)
        #expect(fetchedProviders.first?.customKubeConfigPath == customPath)
    }

    // MARK: - [TC-E01] Auto-Save Flushed On Disappear
    @Test("TC-E01: Inspector auto-save flush immediately persists changes")
    func testInspectorAutoSaveFlushImmediatelyPersists() async throws {
        let harness = ServicesTestHarness()
        let (service, provider) = try await harness.seedServiceWithProvider(
            name: "Initial Name",
            providerType: .shell
        )

        let vm = ServiceInspectorViewModel(
            serviceID: service.id,
            workspaceID: harness.defaultWorkspaceID,
            serviceRepository: harness.serviceRepository
        )
        await vm.loadService(id: service.id)

        // Modify in-memory state and schedule auto-save
        vm.service?.name = "Name Edited Right Before Close"
        vm.scheduleAutoSave()

        // Flush immediately without waiting for 300ms debounce
        await vm.flushPendingAutoSave()

        // Verify SQLite was updated
        let updated = try await harness.serviceRepository.fetchService(id: service.id)
        #expect(updated?.name == "Name Edited Right Before Close")
    }

    // MARK: - [TC-E02] Clear Logs Scoped To Service ID
    @Test("TC-E02: LogAggregator.clear(serviceID:) removes only target service logs")
    func testClearLogsScopedToServiceID() async {
        let aggregator = LogAggregator.shared
        let serviceA = UUID()
        let serviceB = UUID()

        aggregator.append(serviceID: serviceA, serviceName: "Service A", level: "INFO", message: "Log from A 1")
        aggregator.append(serviceID: serviceB, serviceName: "Service B", level: "INFO", message: "Log from B 1")
        aggregator.append(serviceID: serviceA, serviceName: "Service A", level: "INFO", message: "Log from A 2")

        #expect(aggregator.entries.contains(where: { $0.serviceID == serviceA }))
        #expect(aggregator.entries.contains(where: { $0.serviceID == serviceB }))

        // Clear only service A
        aggregator.clear(serviceID: serviceA)

        #expect(!aggregator.entries.contains(where: { $0.serviceID == serviceA }), "Service A logs must be cleared")
        #expect(aggregator.entries.contains(where: { $0.serviceID == serviceB }), "Service B logs must remain intact")
    }

    // MARK: - [TC-B06] DataPort Export Credential Encryption
    @Test("TC-B06: DataPort export keeps credentials protected and does not leak plaintext")
    func testDataPortExportCredentialEncryption() async throws {
        let harness = ServicesTestHarness()
        let secretPass = "TopSecretSSHKeyPassword999!"

        let (service, _) = try await harness.seedServiceWithProvider(
            name: "Secure SSH Host",
            providerType: .ssh,
            sshPassword: secretPass
        )

        let dataPortRepo = DataPortRepository(dbWriter: harness.databaseQueue)
        let backup = try await dataPortRepo.exportData(scope: .service(service.id))

        let exportedProv = backup.providers.first(where: { $0.serviceID == service.id })
        #expect(exportedProv != nil)
        #expect(exportedProv?.sshPassword != secretPass, "Exported backup JSON must not leak plain passwords")
    }
}
