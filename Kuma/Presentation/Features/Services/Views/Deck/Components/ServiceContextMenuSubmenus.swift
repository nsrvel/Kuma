import SwiftUI

public struct ServiceProviderSwitchSubmenu: View {
    public let snapshot: ServiceCardSnapshot
    public let onSwitchProvider: (UUID) -> Void

    public var body: some View {
        Menu {
            if !snapshot.providerOptions.isEmpty {
                ForEach(snapshot.providerOptions) { option in
                    Button {
                        onSwitchProvider(option.id)
                    } label: {
                        HStack {
                            Text(option.label)
                            if option.isActive { Image(systemName: "checkmark") }
                        }
                    }
                }
            } else {
                Button {} label: {
                    HStack {
                        Text(snapshot.providerCategory.sidebarLabel)
                        Image(systemName: "checkmark")
                    }
                }
                .disabled(true)
            }
        } label: {
            Label("Switch Provider", systemImage: "arrow.triangle.2.circlepath")
        }
    }
}

public struct ServiceGroupsSubmenu: View {
    public let groups: [ServiceGroup]
    public let selectedGroupIDs: Set<UUID>
    public let onToggleGroup: (UUID) -> Void

    public var body: some View {
        if !groups.isEmpty {
            Menu {
                ForEach(groups) { group in
                    Button {
                        onToggleGroup(group.id)
                    } label: {
                        HStack {
                            Text(group.name)
                            if selectedGroupIDs.contains(group.id) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Groups", systemImage: "folder")
            }
        }
    }
}
