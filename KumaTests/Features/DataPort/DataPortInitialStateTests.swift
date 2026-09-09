import Foundation
import Testing
@testable import Kuma

@Suite("DataPort Category A: Initial State, Scopes & Wrap Contracts", .serialized)
@MainActor
struct DataPortInitialStateTests {

    // MARK: - [TC-A01] KumaBackup Default Properties
    @Test("TC-A01: Inisialisasi KumaBackup tanpa parameter menghasilkan default yang valid")
    func testKumaBackupDefaultProperties() {
        let backup = DataPortService.KumaBackup()

        #expect(backup.version == DataPortService.currentVersion)
        #expect(backup.workspaces.isEmpty)
        #expect(backup.services.isEmpty)
        #expect(backup.providers.isEmpty)
        #expect(backup.portMappings.isEmpty)
        #expect(backup.kubeConfigs.isEmpty)
        #expect(backup.groups == nil)
        #expect(backup.workspaceImages == nil)
        #expect(backup.exportedAt.timeIntervalSince1970 > 0)
    }

    // MARK: - [TC-A02] KumaBackup Deterministic ID
    @Test("TC-A02: Generate id dari KumaBackup stabil dan memuat versi, timestamp, dan count")
    func testKumaBackupDeterministicID() {
        let date = Date(timeIntervalSince1970: 1700000000)
        let backup = DataPortService.KumaBackup(
            version: 1,
            exportedAt: date,
            workspaces: [Workspace(name: "Alpha"), Workspace(name: "Beta")]
        )

        #expect(backup.id == "1_1700000000.0_2")
    }

    // MARK: - [TC-A03] Backup Date String Formatting
    @Test("TC-A03: backupDateString menghasilkan format yyyy-MM-dd yang valid")
    func testBackupDateStringFormatting() {
        let dateStr = DataPortService.backupDateString
        #expect(dateStr.count == 10)

        // Verifikasi pattern YYYY-MM-DD
        let parts = dateStr.components(separatedBy: "-")
        #expect(parts.count == 3)
        #expect(parts[0].count == 4) // Year
        #expect(parts[1].count == 2) // Month
        #expect(parts[2].count == 2) // Day
    }

    // MARK: - [TC-A04] SingleServiceExport Wrap to Backup
    @Test("TC-A04: wrapSingleService mengkonversi SingleServiceExport menjadi KumaBackup valid")
    func testSingleServiceExportWrapToBackup() {
        let service = DataPortService.ExportService(
            name: "Redis Cache",
            icon: "shippingbox",
            colorHex: "#FF0000"
        )
        let provider = DataPortService.ExportProvider(
            serviceID: service.id,
            type: "docker",
            yamlConfig: "image: redis:alpine"
        )
        let port = DataPortService.ExportPortMapping(
            providerID: provider.id,
            localPort: 6379,
            remotePort: 6379
        )

        let singleExport = DataPortService.SingleServiceExport(
            service: service,
            providers: [provider],
            portMappings: [port]
        )

        let targetWS = UUID()
        let wrappedBackup = DataPortService.wrapSingleService(singleExport, targetWorkspaceID: targetWS)

        #expect(wrappedBackup.services.count == 1)
        #expect(wrappedBackup.services.first?.name == "Redis Cache")
        #expect(wrappedBackup.services.first?.workspaceID == targetWS)
        #expect(wrappedBackup.providers.count == 1)
        #expect(wrappedBackup.portMappings.count == 1)
    }

    // MARK: - [TC-A05] DataPortScope Definition
    @Test("TC-A05: DataPortScope enum mematuhi Equatable dan Sendable")
    func testDataPortScopeDefinition() {
        let uuid = UUID()
        let scopeAll = DataPortService.DataPortScope.all
        let scopeWS = DataPortService.DataPortScope.workspace(uuid)
        let scopeSvc = DataPortService.DataPortScope.service(uuid)

        #expect(scopeAll == .all)
        #expect(scopeWS == .workspace(uuid))
        #expect(scopeSvc == .service(uuid))
        #expect(scopeWS != scopeAll)
    }

    // MARK: - [TC-A06] ExportProvider Category Mapping
    @Test("TC-A06: Mapping seluruh enum raw string ke ProviderCategory terdefinisi dengan tepat")
    func testExportProviderCategoryMapping() {
        let testCases: [(String, ProviderCategory)] = [
            ("docker", .docker),
            ("podman", .podman),
            ("kubernetes", .kubernetes),
            ("kube_port_forward", .kubernetes),
            ("shell", .shell),
            ("ssh", .ssh),
            ("http_check", .httpCheck),
            ("httpCheck", .httpCheck),
            ("tunnel", .tunnel),
            ("process_monitor", .processMonitor),
            ("processMonitor", .processMonitor),
            ("unknown_category", .docker) // Fallback default
        ]

        for (rawType, expectedCategory) in testCases {
            let p = DataPortService.ExportProvider(serviceID: UUID(), type: rawType)
            #expect(p.category == expectedCategory)
        }
    }
}
