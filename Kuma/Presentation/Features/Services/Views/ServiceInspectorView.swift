import SwiftUI

public struct ServiceInspectorView: View {
    public let serviceID: UUID
    public let workspaceID: UUID
    @Bindable var viewModel: ServicesDeckViewModel

    public init(
        serviceID: UUID,
        workspaceID: UUID,
        viewModel: ServicesDeckViewModel
    ) {
        self.serviceID = serviceID
        self.workspaceID = workspaceID
        self.viewModel = viewModel
    }

    private var snapshot: ServiceCardSnapshot? {
        viewModel.snapshots.first(where: { $0.id == serviceID })
    }

    public var body: some View {
        VStack(spacing: KumaSpacing.md) {
            Spacer()

            Image(systemName: "sidebar.right")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)

            Text(snapshot?.name ?? "Service Inspector")
                .font(KumaFont.heading)
                .foregroundStyle(.primary)

            Text("Configuration and live monitoring panel")
                .font(KumaFont.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(KumaSpacing.lg)
    }
}
