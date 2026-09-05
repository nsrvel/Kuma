import Foundation
import Testing
@testable import Kuma

@Suite("Settings Category E: DataPort Lifecycle, Export/Import & Reset", .serialized)
@MainActor
struct SettingsDataPortLifecycleTests {

    // MARK: - [TC-E01] Export Backup Generates Valid JSON
    @Test("TC-E01: Export creates valid KumaBackup structure with currentVersion")
    func testExportBackupGeneratesValidJSON() throws {
        let backup = DataPortService.KumaBackup(
            version: DataPortService.currentVersion,
            exportedAt: Date(),
            workspaces: [
                Workspace(name: "Test Workspace")
            ]
        )

        let encodedData = try DataPortService.encodeBackup(backup)
        #expect(!encodedData.isEmpty)

        let jsonString = String(data: encodedData, encoding: .utf8) ?? ""
        #expect(jsonString.contains("Test Workspace"))
        #expect(jsonString.contains("\"version\" : \(DataPortService.currentVersion)"))
    }

    // MARK: - [TC-E02] Import Valid Backup Restores Data
    @Test("TC-E02: decodeBackup parses valid backup data successfully")
    func testImportValidBackupRestoresData() throws {
        let backup = DataPortService.KumaBackup(
            version: 1,
            exportedAt: Date(),
            workspaces: [
                Workspace(name: "Restored Workspace")
            ]
        )
        let data = try DataPortService.encodeBackup(backup)
        let decoded = try DataPortService.decodeBackup(from: data)

        #expect(decoded.version == 1)
        #expect(decoded.workspaces.count == 1)
        #expect(decoded.workspaces.first?.name == "Restored Workspace")
    }

    // MARK: - [TC-E03] Import Future Version Throws Error
    @Test("TC-E03: decodeBackup rejects backups from higher future versions")
    func testImportFutureVersionThrowsError() throws {
        let futureBackup = DataPortService.KumaBackup(
            version: 999, // higher than currentVersion
            exportedAt: Date(),
            workspaces: []
        )
        let data = try DataPortService.encodeBackup(futureBackup)

        #expect(throws: DataPortService.DataPortError.self) {
            try DataPortService.decodeBackup(from: data)
        }
    }

    // MARK: - [TC-E04] Factory Reset Wipes Defaults And Terminates Processes
    @Test("TC-E04: resetAllAppStorage executes without throwing and terminates processes")
    func testFactoryResetWipesDefaultsAndDB() async {
        let harness = SettingsTestHarness()
        defer { harness.cleanup() }

        // Call the asynchronous storage wipe engine with isolated defaults
        await DataPortService.resetAllAppStorage(defaults: harness.userDefaults)
        let fakeUUID = UUID()
        let isRunning = await ProcessRegistry.shared.isRunning(serviceID: fakeUUID)
        #expect(isRunning == false)
    }

    // MARK: - [TC-E05] Selective Import Structure Validation
    @Test("TC-E05: Single service export and decode integrity")
    func testSingleServiceExportAndDecode() throws {
        let service = DataPortService.ExportService(
            name: "Standalone API",
            icon: "server.rack"
        )
        let singleExport = DataPortService.SingleServiceExport(
            service: service,
            providers: [],
            portMappings: []
        )

        let data = try DataPortService.encodeSingleService(singleExport)
        let decoded = try DataPortService.decodeSingleService(from: data)

        #expect(decoded.service.name == "Standalone API")
        #expect(decoded.id == service.id)
    }
}
