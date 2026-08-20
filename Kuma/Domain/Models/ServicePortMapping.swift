import Foundation

public struct ServicePortMapping: Identifiable, Codable, Equatable, Sendable, Hashable {
    public var id: UUID
    public var serviceID: UUID?
    public var localPort: Int
    public var remotePort: Int
    public var protocolType: String

    public nonisolated init(
        id: UUID = UUID(),
        serviceID: UUID? = nil,
        localPort: Int,
        remotePort: Int,
        protocolType: String = "TCP"
    ) {
        self.id = id
        self.serviceID = serviceID
        self.localPort = localPort
        self.remotePort = remotePort
        self.protocolType = protocolType
    }

    public nonisolated var displayString: String {
        "\(localPort):\(remotePort)"
    }
}
