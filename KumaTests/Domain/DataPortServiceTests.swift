import Testing
import Foundation
@testable import Kuma

@Suite("DataPortService Tests")
struct DataPortServiceTests {

    @Test("Encode and Decode KumaBackup roundtrip")
    func testBackupRoundtrip() throws {
        let ws1 = Workspace(id: UUID(), name: "Backend Cluster")
        let ws2 = Workspace(id: UUID(), name: "Frontend App")

        let original = DataPortService.KumaBackup(
            version: 1,
            exportedAt: Date(),
            workspaces: [ws1, ws2],
            services: [
                DataPortService.ExportService(id: UUID(), name: "PostgreSQL 16", workspaceID: ws1.id)
            ],
            providers: [
                DataPortService.ExportProvider(id: UUID(), serviceID: UUID(), type: "docker", label: "Dev Postgres")
            ],
            portMappings: [
                DataPortService.ExportPortMapping(id: UUID(), providerID: UUID(), localPort: 5432, remotePort: 5432)
            ],
            kubeConfigs: []
        )

        let encoded = try DataPortService.encodeBackup(original)
        #expect(!encoded.isEmpty)

        let decoded = try DataPortService.decodeBackup(from: encoded)
        #expect(decoded.version == 1)
        #expect(decoded.workspaces.count == 2)
        #expect(decoded.workspaces[0].name == "Backend Cluster")
        #expect(decoded.services.count == 1)
        #expect(decoded.services[0].name == "PostgreSQL 16")
        #expect(decoded.providers.count == 1)
        #expect(decoded.providers[0].type == "docker")
        #expect(decoded.portMappings.count == 1)
        #expect(decoded.portMappings[0].localPort == 5432)
    }

    @Test("Decode real Kuma V3 backup JSON file")
    func testDecodeV3BackupJSON() throws {
        let sampleV3JSON = """
        {
          "exportedAt" : "2026-08-07T09:54:58Z",
          "kubeConfigs" : [],
          "portMappings" : [
            {
              "id" : "C58927B8-3521-4648-9394-5383ECDA0153",
              "localPort" : 9094,
              "providerID" : "0C697839-9B4E-49A1-AD47-0E1ADE05B92D",
              "remotePort" : 9094
            }
          ],
          "providers" : [
            {
              "id" : "0C697839-9B4E-49A1-AD47-0E1ADE05B92D",
              "label" : "Kafka Broker",
              "serviceID" : "332FDABD-01E4-4B00-85B1-130B3D0899E3",
              "type" : "docker"
            }
          ],
          "services" : [
            {
              "id" : "332FDABD-01E4-4B00-85B1-130B3D0899E3",
              "name" : "Kafka Cluster",
              "workspaceID" : "8F635D01-1BE8-4E80-997A-8DFF1782BE33"
            }
          ],
          "version" : 1,
          "workspaces" : [
            {
              "createdAt" : "2026-08-07T09:50:00Z",
              "id" : "8F635D01-1BE8-4E80-997A-8DFF1782BE33",
              "isDefault" : true,
              "name" : "Default Workspace",
              "updatedAt" : "2026-08-07T09:50:00Z"
            }
          ]
        }
        """

        let data = sampleV3JSON.data(using: .utf8)!
        let backup = try DataPortService.decodeBackup(from: data)

        #expect(backup.version == 1)
        #expect(backup.workspaces.count == 1)
        #expect(backup.workspaces[0].name == "Default Workspace")
        #expect(backup.services.count == 1)
        #expect(backup.services[0].name == "Kafka Cluster")
        #expect(backup.providers.count == 1)
        #expect(backup.providers[0].label == "Kafka Broker")
        #expect(backup.portMappings.count == 1)
        #expect(backup.portMappings[0].localPort == 9094)
    }
}
