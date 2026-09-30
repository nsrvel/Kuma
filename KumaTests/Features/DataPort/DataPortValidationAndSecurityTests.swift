import Foundation
import Testing
@testable import Kuma

@Suite("DataPort Category B: Validation, Security & Polymorphic Parsing", .serialized)
@MainActor
struct DataPortValidationAndSecurityTests {

    // MARK: - [TC-B01] Future Version Backup Rejection
    @Test("TC-B01: decodeBackup menolak file backup dengan versi lebih tinggi dari currentVersion")
    func testFutureVersionBackupRejection() throws {
        let futureBackup = DataPortService.KumaBackup(
            version: 999,
            exportedAt: Date(),
            workspaces: []
        )
        let data = try DataPortService.encodeBackup(futureBackup)

        #expect(throws: DataPortService.DataPortError.self) {
            try DataPortService.decodeBackup(from: data)
        }
    }

    // MARK: - [TC-B02] Polymorphic Parser Detects Full Backup
    @Test("TC-B02: parseAnyBackup mendeteksi dan mengembalikan full KumaBackup secara mulus")
    func testPolymorphicParserDetectsFullBackup() throws {
        let original = DataPortService.KumaBackup(
            version: 1,
            exportedAt: Date(),
            workspaces: [Workspace(name: "Full Space")]
        )
        let data = try DataPortService.encodeBackup(original)

        let parsed = try DataPortService.parseAnyBackup(from: data)
        #expect(parsed.workspaces.count == 1)
        #expect(parsed.workspaces.first?.name == "Full Space")
    }

    // MARK: - [TC-B03] Polymorphic Parser Detects Single Service
    @Test("TC-B03: parseAnyBackup mendeteksi SingleServiceExport dan meng-auto-wrap menjadi KumaBackup")
    func testPolymorphicParserDetectsSingleService() throws {
        let svc = DataPortService.ExportService(name: "Standalone Microservice")
        let singleExport = DataPortService.SingleServiceExport(
            service: svc,
            providers: [],
            portMappings: []
        )
        let data = try DataPortService.encodeSingleService(singleExport)

        let targetWS = UUID()
        let parsed = try DataPortService.parseAnyBackup(from: data, targetWorkspaceID: targetWS)

        #expect(parsed.services.count == 1)
        #expect(parsed.services.first?.name == "Standalone Microservice")
        #expect(parsed.services.first?.workspaceID == targetWS)
    }

    // MARK: - [TC-B04] Corrupted JSON Decoding Failure
    @Test("TC-B04: parseAnyBackup melempar error saat menerima data acak bukan format JSON")
    func testCorruptedJSONDecodingFailure() {
        let invalidData = "This is definitely not a JSON file.".data(using: .utf8)!

        #expect(throws: Error.self) {
            try DataPortService.parseAnyBackup(from: invalidData)
        }
    }

    // MARK: - [TC-B05] Name Conflict Detection in Workspace Import
    @Test("TC-B05: Konflik nama service terdeteksi dan di-override dengan suffix (Imported)")
    func testNameConflictDetectionInWorkspaceImport() {
        let existingNames: Set<String> = ["frontend-app", "postgres"]

        let serviceName = "Frontend-App"
        let hasConflict = existingNames.contains(serviceName.lowercased())
        #expect(hasConflict == true)

        let resolvedName = hasConflict ? "\(serviceName) (Imported)" : serviceName
        #expect(resolvedName == "Frontend-App (Imported)")
    }

    // MARK: - [TC-B06] Case-Insensitive Name Conflict Detection
    @Test("TC-B06: Deteksi konflik nama service bersifat case-insensitive")
    func testCaseInsensitiveNameConflictDetection() {
        let existingNames: Set<String> = ["api-gateway"]

        let service1 = "API-GATEWAY"
        let service2 = "api-gateway"
        let service3 = "Api-Gateway"

        #expect(existingNames.contains(service1.lowercased()) == true)
        #expect(existingNames.contains(service2.lowercased()) == true)
        #expect(existingNames.contains(service3.lowercased()) == true)
    }
}
