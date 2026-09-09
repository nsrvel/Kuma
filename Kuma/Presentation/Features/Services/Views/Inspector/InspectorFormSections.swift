import SwiftUI

public struct InspectorFormSections: View {
    @Binding public var provider: Provider
    @Binding public var ports: [KumaPortMappingItem]
    public var kubeConfigVM: KubeConfigViewModel?
    public let isLocked: Bool
    public let onFieldChanged: () -> Void

    public init(
        provider: Binding<Provider>,
        ports: Binding<[KumaPortMappingItem]>,
        kubeConfigVM: KubeConfigViewModel? = nil,
        isLocked: Bool = false,
        onFieldChanged: @escaping () -> Void = {}
    ) {
        self._provider = provider
        self._ports = ports
        self.kubeConfigVM = kubeConfigVM
        self.isLocked = isLocked
        self.onFieldChanged = onFieldChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch provider.type {
            case .kubernetes:
                InspectorKubernetesFormSection(
                    provider: $provider,
                    kubeConfigVM: kubeConfigVM,
                    isLocked: isLocked,
                    onFieldChanged: onFieldChanged
                )

            case .docker:
                InspectorComposeFormSection(
                    provider: $provider,
                    isLocked: isLocked,
                    isPodman: false,
                    onFieldChanged: onFieldChanged
                )

            case .podman:
                InspectorComposeFormSection(
                    provider: $provider,
                    isLocked: isLocked,
                    isPodman: true,
                    onFieldChanged: onFieldChanged
                )

            case .shell, .ssh, .httpCheck, .tunnel, .processMonitor:
                InspectorRemoteAndNetworkFormSections(
                    provider: $provider,
                    isLocked: isLocked,
                    onFieldChanged: onFieldChanged
                )
            }

            if provider.type == .kubernetes || provider.type == .ssh {
                KumaFormSection(icon: "arrow.left.arrow.right", title: "Ports") {
                    KumaPortMappingEditor(label: "", items: $ports)
                        .disabled(isLocked)
                        .onChange(of: ports) { _, _ in
                            onFieldChanged()
                        }
                }
            }
        }
    }
}
