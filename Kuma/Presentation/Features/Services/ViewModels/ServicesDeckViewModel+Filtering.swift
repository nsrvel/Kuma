import Foundation

extension ServicesDeckViewModel {
    var bulkActionSnapshots: [ServiceCardSnapshot] {
        filteredSnapshots
    }

    func recomputeFilteredSnapshots() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let hasSearch = !query.isEmpty
        let hasStatusFilter = !selectedStatuses.isEmpty
        let hasProviderFilter = !selectedProviders.isEmpty
        let starredOnly = isStarredOnly
        let targetGroupID = filterGroupID

        var result = snapshots.filter { snapshot in
            if starredOnly && !snapshot.isStarred {
                return false
            }
            if let targetGroupID, !snapshot.groupIDs.contains(targetGroupID) {
                return false
            }
            if hasSearch {
                if !snapshot.searchKey.contains(query) {
                    return false
                }
            }

            if hasStatusFilter {
                if snapshot.isDisabled {
                    if !selectedStatuses.contains(.disabled) { return false }
                } else {
                    let state = runtime(for: snapshot.id).status
                    switch state {
                    case .running, .starting:
                        if !selectedStatuses.contains(.running) { return false }
                    case .stopped, .stopping:
                        if !selectedStatuses.contains(.stopped) { return false }
                    case .crashed:
                        if !selectedStatuses.contains(.crashed) { return false }
                    }
                }
            }

            if hasProviderFilter {
                if !selectedProviders.contains(snapshot.providerCategory) { return false }
            }

            return true
        }

        switch sortBy {
        case .name:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .status:
            let statusPriority: [UUID: Int] = Dictionary(
                uniqueKeysWithValues: result.map { snapshot in
                    let priority = snapshot.isDisabled ? 5 : runtime(for: snapshot.id).status.sortPriority
                    return (snapshot.id, priority)
                }
            )
            result.sort { a, b in
                let priorityA = statusPriority[a.id] ?? 5
                let priorityB = statusPriority[b.id] ?? 5
                if priorityA != priorityB {
                    return priorityA < priorityB
                }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        case .created:
            result.sort { $0.createdAt > $1.createdAt }
        }

        filteredSnapshots = result
        filterVersion += 1
    }
}
