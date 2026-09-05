import SwiftUI

public struct SettingsPortsConnectionsSection: View {
    @Bindable var viewModel: SettingsViewModel

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        KumaFormSection(
            icon: "arrow.left.arrow.right",
            title: "Ports & Connections"
        ) {
            KumaRowPickerField(
                label: "Port Conflict Action",
                description: "Determine behavior when a service port is already in use by another process.",
                options: PortConflictPolicy.allCases.map(\.rawValue),
                selection: Binding(
                    get: { viewModel.portConflictPolicy.rawValue },
                    set: { if let p = PortConflictPolicy(rawValue: $0) { viewModel.portConflictPolicy = p } }
                ),
                titleResolver: { (PortConflictPolicy(rawValue: $0) ?? .warnAndBlock).title }
            )
        }
    }
}
