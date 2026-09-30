import SwiftUI

/// Table list with isolated `ServiceStateStore` access (not on the card grid parent).
struct ServiceDeckTableSection: View {
    let viewModel: ServicesDeckViewModel
    let actions: ServiceDeckActions

    @Environment(ServiceStateStore.self) private var serviceStateStore

    var body: some View {
        ServiceTableView(
            snapshots: viewModel.filteredSnapshots,
            selectedID: viewModel.selectedServiceID,
            groupsProvider: actions.groups,
            handlers: actions.tableHandlers
        )
    }
}
