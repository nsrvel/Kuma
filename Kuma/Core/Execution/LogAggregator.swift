import Foundation
import Observation

/// Real-time live log message model
public struct LiveLogEntry: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let serviceID: UUID
    public let serviceName: String
    public let timestamp: String
    public let level: String
    public let message: String

    public init(
        id: UUID = UUID(),
        serviceID: UUID,
        serviceName: String,
        timestamp: String = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium),
        level: String = "INFO",
        message: String
    ) {
        self.id = id
        self.serviceID = serviceID
        self.serviceName = serviceName
        self.timestamp = timestamp
        self.level = level
        self.message = message
    }
}

@Observable
public final class LogAggregator: @unchecked Sendable {
    public nonisolated static let shared = LogAggregator()

    @MainActor public private(set) var entries: [LiveLogEntry] = []
    private let maxEntries = 2000

    private init() {}

    @MainActor
    public func append(serviceID: UUID, serviceName: String, level: String = "INFO", message: String) {
        let lines = message.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)

        for line in lines {
            let entry = LiveLogEntry(serviceID: serviceID, serviceName: serviceName, timestamp: now, level: level, message: line)
            entries.append(entry)
        }

        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    public nonisolated static func appendLog(serviceID: UUID, serviceName: String, level: String = "INFO", message: String) {
        Task { @MainActor in
            shared.append(serviceID: serviceID, serviceName: serviceName, level: level, message: message)
        }
    }

    @MainActor
    public func clear() {
        entries.removeAll()
    }
}
