import Foundation
import Observation

/// Real-time live log message model
public nonisolated struct LiveLogEntry: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let serviceID: UUID
    public let serviceName: String
    public let timestamp: String
    public let level: String
    public let message: String

    public nonisolated init(
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
    public private(set) var availableServiceNames: [String] = []

    private var maxEntriesPerService = 500
    private var maxTotalEntries = 2_000
    private var uiSubscriberCount = 0
    private var serviceNameByID: [UUID: String] = [:]

    public var deliversToUI: Bool { uiSubscriberCount > 0 }

    private init() {
        applyRetentionSettings()
    }

    /// Retain while a live-log UI surface is visible (Live Logs, inspector console).
    public func retainUISubscriber() {
        uiSubscriberCount += 1
    }

    public func releaseUISubscriber() {
        uiSubscriberCount = max(0, uiSubscriberCount - 1)
    }

    public func refreshRetentionFromSettings() {
        applyRetentionSettings()
        trimEntriesIfNeeded()
    }

    public func logs(for serviceID: UUID) -> [LiveLogEntry] {
        Array(entries.lazy.filter { $0.serviceID == serviceID }.suffix(maxEntriesPerService))
    }

    public func append(serviceID: UUID, serviceName: String, level: String = "INFO", message: String) {
        let lines = message.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return }
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)

        for line in lines {
            let entry = LiveLogEntry(serviceID: serviceID, serviceName: serviceName, timestamp: now, level: level, message: line)
            entries.append(entry)
        }

        registerServiceName(serviceID: serviceID, serviceName: serviceName)
        trimEntriesIfNeeded()
    }

    /// Appends multiple log entries in a single transaction to prevent UI thrashing.
    public func appendBatch(_ newEntries: [LiveLogEntry]) {
        guard !newEntries.isEmpty else { return }
        entries.append(contentsOf: newEntries)
        for entry in newEntries {
            registerServiceName(serviceID: entry.serviceID, serviceName: entry.serviceName)
        }
        trimEntriesIfNeeded()
    }

    public func clear(serviceID: UUID? = nil) {
        if let serviceID {
            entries.removeAll(where: { $0.serviceID == serviceID })
            serviceNameByID.removeValue(forKey: serviceID)
        } else {
            entries.removeAll()
            serviceNameByID.removeAll()
        }
        rebuildAvailableServiceNames()
    }

    private func applyRetentionSettings() {
        let limit = LogRetentionLimit.current()
        maxEntriesPerService = limit.maxLinesPerService
        maxTotalEntries = limit.maxTotalLines
    }

    private func registerServiceName(serviceID: UUID, serviceName: String) {
        guard !serviceName.isEmpty else { return }
        if serviceNameByID[serviceID] != serviceName {
            serviceNameByID[serviceID] = serviceName
            rebuildAvailableServiceNames()
        }
    }

    private func rebuildAvailableServiceNames() {
        let namesInEntries = Set(entries.map(\.serviceName).filter { !$0.isEmpty })
        availableServiceNames = Array(namesInEntries).sorted()
    }

    private func trimEntriesIfNeeded() {
        applyRetentionSettings()

        if maxTotalEntries < Int.max, entries.count > maxTotalEntries {
            entries.removeFirst(entries.count - maxTotalEntries)
        }

        if maxEntriesPerService < Int.max {
            trimPerServiceKeepingNewest()
        }

        rebuildAvailableServiceNames()
    }

    private func trimPerServiceKeepingNewest() {
        var kept: [LiveLogEntry] = []
        var counts: [UUID: Int] = [:]
        for entry in entries.reversed() {
            let count = counts[entry.serviceID, default: 0]
            if count < maxEntriesPerService {
                kept.append(entry)
                counts[entry.serviceID] = count + 1
            }
        }
        entries = kept.reversed()
    }
}
