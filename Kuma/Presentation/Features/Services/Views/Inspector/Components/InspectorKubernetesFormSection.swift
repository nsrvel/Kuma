import SwiftUI

public struct InspectorKubernetesFormSection: View {
    @Binding public var provider: Provider
    public var kubeConfigVM: KubeConfigViewModel?
    public let isLocked: Bool
    public let onFieldChanged: () -> Void

    public var body: some View {
        Group {
            if let kubeConfigVM {
                KubeConfigConnectionView(
                    viewModel: kubeConfigVM,
                    isLocked: isLocked,
                    contextToTest: provider.kubeContext ?? "",
                    onConfigChanged: onFieldChanged
                )
                .disabled(isLocked)

                KumaFormSection(icon: "network", title: "Cluster Connection") {
                    KubeConnectionSettingsView(
                        kubeNamespace: Binding(
                            get: { provider.kubeNamespace ?? "" },
                            set: { provider.kubeNamespace = $0.isEmpty ? nil : $0; onFieldChanged() }
                        ),
                        kubeContext: Binding(
                            get: { provider.kubeContext ?? "" },
                            set: { provider.kubeContext = $0.isEmpty ? nil : $0; onFieldChanged() }
                        ),
                        availableContexts: kubeConfigVM.availableContexts
                    )
                    .disabled(isLocked)
                }
            }

            KumaFormSection(icon: "scope", title: "Target Resource") {
                KubeTargetSettingsView(
                    targetName: Binding(
                        get: { provider.targetName ?? "" },
                        set: { provider.targetName = $0.isEmpty ? nil : $0; onFieldChanged() }
                    ),
                    targetType: Binding(
                        get: { KubeTargetType(rawValue: provider.kubeTargetType ?? "") ?? .pod },
                        set: { provider.kubeTargetType = $0.rawValue; onFieldChanged() }
                    ),
                    usePattern: Binding(
                        get: { provider.usePattern ?? true },
                        set: { provider.usePattern = $0; onFieldChanged() }
                    )
                )
                .disabled(isLocked)
            }
        }
    }
}
