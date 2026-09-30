import Foundation

/// Fixed-capacity chronological log buffer with O(1) eviction (PERF-02 / TC-E04).
nonisolated struct LogChronologicalBuffer: Sendable {
    private var slots: [LiveLogEntry?]
    private var head = 0
    private(set) var count = 0

    init(capacity: Int) {
        slots = Array(repeating: nil, count: max(1, capacity))
    }

    var capacity: Int { slots.count }

    func chronologicalEntries() -> [LiveLogEntry] {
        guard count > 0 else { return [] }
        if count < slots.count {
            return slots.prefix(count).compactMap { $0 }
        }
        var ordered: [LiveLogEntry] = []
        ordered.reserveCapacity(count)
        for offset in 0..<count {
            let index = (head + offset) % slots.count
            if let entry = slots[index] {
                ordered.append(entry)
            }
        }
        return ordered
    }

    /// Returns evicted entry when at capacity.
    mutating func append(_ entry: LiveLogEntry) -> LiveLogEntry? {
        if count < slots.count {
            slots[count] = entry
            count += 1
            return nil
        }
        let evicted = slots[head]
        slots[head] = entry
        head = (head + 1) % slots.count
        return evicted
    }

    mutating func removeAll() {
        head = 0
        count = 0
        slots = Array(repeating: nil, count: slots.count)
    }

    mutating func removeAll(where predicate: (LiveLogEntry) -> Bool) -> Set<UUID> {
        let removedIDs = Set(slots.compactMap { entry -> UUID? in
            guard let entry, predicate(entry) else { return nil }
            return entry.id
        })
        guard !removedIDs.isEmpty else { return [] }

        var kept: [LiveLogEntry] = []
        kept.reserveCapacity(count)
        for offset in 0..<count {
            let index = count < slots.count ? offset : (head + offset) % slots.count
            if let entry = slots[index], !removedIDs.contains(entry.id) {
                kept.append(entry)
            }
        }
        removeAll()
        for entry in kept {
            _ = append(entry)
        }
        return removedIDs
    }

    mutating func removeEntries(withIDs ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        let kept = chronologicalEntries().filter { !ids.contains($0.id) }
        removeAll()
        for entry in kept {
            _ = append(entry)
        }
    }

    mutating func reconfigureCapacity(_ newCapacity: Int) {
        let kept = chronologicalEntries()
        slots = Array(repeating: nil, count: max(1, newCapacity))
        head = 0
        count = 0
        for entry in kept.suffix(slots.count) {
            _ = append(entry)
        }
    }
}
