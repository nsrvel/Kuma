import SwiftUI

// MARK: - WorkspaceDangerZoneSection

public struct WorkspaceDangerZoneSection: View {
    public let workspace: Workspace
    public let onDeleteRequest: () -> Void

    public init(workspace: Workspace, onDeleteRequest: @escaping () -> Void) {
        self.workspace = workspace
        self.onDeleteRequest = onDeleteRequest
    }

    public var body: some View {
        KumaFormSection(
            icon: "exclamationmark.triangle.fill",
            title: "Danger Zone",
            style: .danger
        ) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Delete Workspace")
                        .font(KumaFont.body)
                        .foregroundStyle(.red)
                    Text("Permanently remove this workspace and its services.")
                        .font(KumaFont.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Delete…") {
                    onDeleteRequest()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }
}

#Preview {
    WorkspaceDangerZoneSection(
        workspace: Workspace(name: "Staging Cluster"),
        onDeleteRequest: {}
    )
    .padding()
}
