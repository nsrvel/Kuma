import Foundation

/// Legacy runner hook — output is spooled to disk; live logs use `LiveLogSession`.
public actor ServiceLogPipeline {
    public let serviceID: UUID
    public let serviceName: String

    public init(serviceID: UUID, serviceName: String) {
        self.serviceID = serviceID
        self.serviceName = serviceName
    }

    public func ingestRawChunk(_ chunk: String, level: String = "INFO") {}

    public func emit(level: String = "INFO", message: String) {}

    public func finish() {}

    public nonisolated func makeOutputHandler() -> @Sendable (String) -> Void {
        { _ in }
    }
}
