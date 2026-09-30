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

    /// Chronological buffer for Live Logs (global view).
    public private(set) var entries: [LiveLogEntry] = []
    private var chronologicalBuffer = LogChronologicalBuffer(capacity: 2_000)
    public private(set) var availableServiceNames: [String] = []
    /// Bumps on every append, trim, or clear — cheap signal for UI filter caches.
    public private(set) var changeToken: UInt64 = 0

    private var entriesByService: [UUID: [LiveLogEntry]] = [:]
    private var maxEntriesPerService = 500
    private var maxTotalEntries = 2_000
    private var uiSubscriberCount = 0
    private var serviceNameByID: [UUID: String] = [:]

    public var deliversToUI: Bool { uiSubscriberCount > 0 }

    private init() {
        applyRetentionSettings()
    }

    public func retainUISubscriber() {
        uiSubscriberCount += 1
    }

    public func releaseUISubscriber() {
        uiSubscriberCount = max(0, uiSubscriberCount - 1)
    }

    public func refreshRetentionFromSettings() {
        applyRetentionSettings()
        trimAllServices()
        entries = chronologicalBuffer.chronologicalEntries()
        rebuildAvailableServiceNames()
        bumpChangeToken()
    }

    public func logs(for serviceID: UUID) -> [LiveLogEntry] {
        entriesByService[serviceID] ?? []
    }

    public func append(serviceID: UUID, serviceName: String, level: String = "INFO", message: String) {
        let lines = message.components(separatedBy: .newlines).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return }
        let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)

        for line in lines {
            let entry = LiveLogEntry(serviceID: serviceID, serviceName: serviceName, timestamp: now, level: level, message: line)
            ingest(entry)
        }
    }

    public func appendBatch(_ newEntries: [LiveLogEntry]) {
        guard !newEntries.isEmpty else { return }
        for entry in newEntries {
            ingest(entry, bumpToken: false)
        }
        bumpChangeToken()
    }

    private func bumpChangeToken() {
        changeToken += 1
    }

    public func clear(serviceID: UUID? = nil) {
        if let serviceID {
            let removedIDs = chronologicalBuffer.removeAll { $0.serviceID == serviceID }
            if !removedIDs.isEmpty {
                entries = chronologicalBuffer.chronologicalEntries()
            }
            entriesByService.removeValue(forKey: serviceID)
            serviceNameByID.removeValue(forKey: serviceID)
        } else {
            chronologicalBuffer.removeAll()
            entries = []
            entriesByService.removeAll()
            serviceNameByID.removeAll()
        }
        rebuildAvailableServiceNames()
        bumpChangeToken()
    }

    private func ingest(_ entry: LiveLogEntry, bumpToken: Bool = true) {
        registerServiceName(serviceID: entry.serviceID, serviceName: entry.serviceName)

        var serviceLines = entriesByService[entry.serviceID, default: []]
        serviceLines.append(entry)
        if maxEntriesPerService < Int.max, serviceLines.count > maxEntriesPerService {
            let dropCount = serviceLines.count - maxEntriesPerService
            let droppedIDs = Set(serviceLines.prefix(dropCount).map(\.id))
            serviceLines.removeFirst(dropCount)
            chronologicalBuffer.removeEntries(withIDs: droppedIDs)
            entries = chronologicalBuffer.chronologicalEntries()
        }
        entriesByService[entry.serviceID] = serviceLines

        if let evicted = chronologicalBuffer.append(entry) {
            removeEntryFromServiceIndex(evicted)
        }
        entries = chronologicalBuffer.chronologicalEntries()
        if bumpToken { bumpChangeToken() }
    }

    private func applyRetentionSettings() {
        let limit = LogRetentionLimit.current()
        maxEntriesPerService = limit.maxLinesPerService
        maxTotalEntries = limit.maxTotalLines
        if chronologicalBuffer.capacity != maxTotalEntries {
            chronologicalBuffer.reconfigureCapacity(maxTotalEntries)
            entries = chronologicalBuffer.chronologicalEntries()
        }
    }

    private func registerServiceName(serviceID: UUID, serviceName: String) {
        guard !serviceName.isEmpty else { return }
        if serviceNameByID[serviceID] != serviceName {
            serviceNameByID[serviceID] = serviceName
            rebuildAvailableServiceNames()
        }
    }

    private func rebuildAvailableServiceNames() {
        let namesInEntries = Set(serviceNameByID.values.filter { !$0.isEmpty })
        availableServiceNames = Array(namesInEntries).sorted()
    }

    private func trimAllServices() {
        guard maxEntriesPerService < Int.max else { return }
        var droppedIDs = Set<UUID>()
        for serviceID in Array(entriesByService.keys) {
            guard var list = entriesByService[serviceID], list.count > maxEntriesPerService else { continue }
            let dropCount = list.count - maxEntriesPerService
            droppedIDs.formUnion(list.prefix(dropCount).map(\.id))
            list.removeFirst(dropCount)
            entriesByService[serviceID] = list
        }
        if !droppedIDs.isEmpty {
            chronologicalBuffer.removeEntries(withIDs: droppedIDs)
            entries = chronologicalBuffer.chronologicalEntries()
        }
    }

    private func removeEntryFromServiceIndex(_ entry: LiveLogEntry) {
        guard var list = entriesByService[entry.serviceID] else { return }
        if let idx = list.firstIndex(where: { $0.id == entry.id }) {
            list.remove(at: idx)
        }
        if list.isEmpty {
            entriesByService.removeValue(forKey: entry.serviceID)
            if !entries.contains(where: { $0.serviceID == entry.serviceID }) {
                serviceNameByID.removeValue(forKey: entry.serviceID)
            }
        } else {
            entriesByService[entry.serviceID] = list
        }
    }
}
