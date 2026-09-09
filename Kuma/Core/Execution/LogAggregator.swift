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

/// Thread-safe in-memory live log manager isolated to MainActor for smooth 120fps UI consumption.
@Observable
@MainActor
public final class LogAggregator {
    public static let shared = LogAggregator()

    public private(set) var entries: [LiveLogEntry] = []
    public private(set) var entriesByService: [UUID: [LiveLogEntry]] = [:]
    private let maxEntriesPerService = 500
    private let maxTotalEntries = 2000

    private init() {}

    public func logs(for serviceID: UUID) -> [LiveLogEntry] {
        entriesByService[serviceID] ?? []
    }

    public func append(serviceID: UUID, serviceName: String, level: String = "INFO", message: String) {
        let lines = message.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return }
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)

        var serviceList = entriesByService[serviceID] ?? []

        for line in lines {
            let entry = LiveLogEntry(serviceID: serviceID, serviceName: serviceName, timestamp: now, level: level, message: line)
            entries.append(entry)
            serviceList.append(entry)
        }

        if serviceList.count > maxEntriesPerService {
            serviceList.removeFirst(serviceList.count - maxEntriesPerService)
        }
        entriesByService[serviceID] = serviceList

        if entries.count > maxTotalEntries {
            entries.removeFirst(entries.count - maxTotalEntries)
        }
    }

    /// Convenience static method safely bridging background threads to MainActor.
    public nonisolated static func appendLog(serviceID: UUID, serviceName: String, level: String = "INFO", message: String) {
        Task { @MainActor in
            shared.append(serviceID: serviceID, serviceName: serviceName, level: level, message: message)
        }
    }

    public func clear(serviceID: UUID? = nil) {
        if let serviceID {
            entriesByService.removeValue(forKey: serviceID)
            entries.removeAll(where: { $0.serviceID == serviceID })
        } else {
            entriesByService.removeAll()
            entries.removeAll()
        }
    }
}
