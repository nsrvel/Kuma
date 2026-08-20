import Foundation

public struct InspectorData: Sendable, Equatable {
    public let service: Service
    public let provider: Provider
    public let portMappings: [ServicePortMapping]

    public init(
        service: Service,
        provider: Provider,
        portMappings: [ServicePortMapping] = []
    ) {
        self.service = service
        self.provider = provider
        self.portMappings = portMappings
    }
}
