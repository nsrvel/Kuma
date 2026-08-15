import SwiftUI

public struct SettingsView: View {
    @Bindable var store: SettingsStore
    @Bindable var workspaceStore: WorkspaceStore

    public init(store: SettingsStore, workspaceStore: WorkspaceStore) {
        self.store = store
        self.workspaceStore = workspaceStore
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: KumaSpacing.xxl) {
                // User & App Preferences
                SettingsGeneralSection(store: store)
                SettingsAppearanceSection(store: store)
                SettingsNotificationsSection(store: store)

                // Developer & Engine Tools
                SettingsCLIToolsSection(store: store)
                SettingsTunnelingToolsSection(store: store)
                SettingsLogsSection(store: store)

                // Data & Storage Management
                SettingsDataSection(workspaceStore: workspaceStore)
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
        store: SettingsStore(),
        workspaceStore: WorkspaceStore()
    )
    .frame(width: 750, height: 800)
}
