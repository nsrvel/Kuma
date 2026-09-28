import SwiftUI

/// Keeps one `ServicesDeckViewModel` per workspace so sidebar filter switches do not reload the deck.
struct WorkspaceServicesDeckHost: View {
    let workspaceID: UUID
    let selectedSidebarID: UUID?
    @Bindable var sidebarViewModel: SidebarViewModel

    @State private var viewModel = ServicesDeckViewModel()
    @Environment(ServiceStateStore.self) private var serviceStateStore

    private var isStarredOnly: Bool {
        selectedSidebarID == .stable("starred-services")
    }

    private var filterGroupID: UUID? {
        sidebarViewModel.groupIDForSelectedRow(selectedSidebarID)
    }

    var body: some View {
        ServicesDeckView(
            workspaceID: workspaceID,
            viewModel: viewModel,
            isStarredOnly: isStarredOnly,
            filterGroupID: filterGroupID
        )
        .task(id: workspaceID) {
            viewModel.stateStore = serviceStateStore
            syncSidebarFiltersToViewModel()
            await viewModel.loadWorkspaceAsync(workspaceID: workspaceID)
        }
        .onChange(of: selectedSidebarID) { _, _ in
            syncSidebarFiltersToViewModel(animated: true)
        }
        .onChange(of: isStarredOnly) { _, newStarred in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                viewModel.isStarredOnly = newStarred
            }
        }
        .onChange(of: filterGroupID) { _, newGroupID in
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                viewModel.filterGroupID = newGroupID
            }
        }
    }

    private func syncSidebarFiltersToViewModel(animated: Bool = false) {
        let apply = {
            viewModel.isStarredOnly = isStarredOnly
            viewModel.filterGroupID = filterGroupID
        }
        if animated {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                apply()
            }
        } else {
            apply()
        }
    }
}
