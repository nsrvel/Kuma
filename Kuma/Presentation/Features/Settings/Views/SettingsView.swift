import SwiftUI

public struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    @Bindable var workspaceStore: WorkspaceStore

    public init(viewModel: SettingsViewModel, workspaceStore: WorkspaceStore) {
        self.viewModel = viewModel
        self.workspaceStore = workspaceStore
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: KumaSpacing.xxl) {
                // User & App Preferences
                SettingsGeneralSection(viewModel: viewModel)
                SettingsAppearanceSection(viewModel: viewModel)
                SettingsNotificationsSection(viewModel: viewModel)

                // Developer & Engine Tools
                SettingsCLIToolsSection(viewModel: viewModel)
                SettingsTunnelingToolsSection(viewModel: viewModel)
                SettingsPortsConnectionsSection(viewModel: viewModel)
                SettingsLogsSection(viewModel: viewModel)

                // Data & Storage Management
                SettingsDataSection(viewModel: viewModel, workspaceStore: workspaceStore)
            }
            .padding(.horizontal, KumaSpacing.xxl)
            .padding(.vertical, KumaSpacing.xl)
            .frame(maxWidth: 800)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView(
        viewModel: SettingsViewModel(),
        workspaceStore: WorkspaceStore()
    )
    .frame(width: 750, height: 800)
}
