import SwiftUI

// MARK: - KubeClusterAndTargetSectionView

/// Unified Kubernetes Cluster Connection and Target Resource Configuration Section.
public struct KubeClusterAndTargetSectionView: View {
    @Binding public var kubeContext: String
    @Binding public var kubeNamespace: String
    @Binding public var targetType: KubeTargetType
    @Binding public var usePattern: Bool
    @Binding public var targetName: String
    public var availableContexts: [String]

    public init(
        kubeContext: Binding<String>,
        kubeNamespace: Binding<String>,
        targetType: Binding<KubeTargetType>,
        usePattern: Binding<Bool>,
        targetName: Binding<String>,
        availableContexts: [String] = []
    ) {
        self._kubeContext = kubeContext
        self._kubeNamespace = kubeNamespace
        self._targetType = targetType
        self._usePattern = usePattern
        self._targetName = targetName
        self.availableContexts = availableContexts
    }

    private var contextOptions: [String] {
        if availableContexts.isEmpty {
            return kubeContext.isEmpty ? [""] : [kubeContext]
        }
        if !kubeContext.isEmpty && !availableContexts.contains(kubeContext) {
            return [kubeContext] + availableContexts
        }
        return availableContexts
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Cluster Connection Fields (Always Dropdown Picker)
            KumaRowPickerField(
                label: "Context",
                description: "Target Kubernetes context from selected config.",
                options: contextOptions,
                selection: $kubeContext,
                titleResolver: { opt in
                    if opt.isEmpty {
                        return availableContexts.isEmpty ? "No Contexts Available" : "Select Context..."
                    }
                    return opt
                }
            )
            .disabled(availableContexts.isEmpty)

            Divider().opacity(0.3)

            KumaTextField(
                label: "Namespace",
                value: $kubeNamespace,
                placeholder: "staging"
            )

            Divider().opacity(0.3)

            // Target Resource Fields
            KumaRowPickerField(
                label: "Target Type",
                description: "Kubernetes resource type to port-forward to.",
                options: KubeTargetType.allCases,
                selection: $targetType,
                titleResolver: { $0.label }
            )

            Divider().opacity(0.3)

            KumaToggleField(
                label: "Pattern Matching",
                value: $usePattern,
                description: "Match target resource using fuzzy or substring pattern."
            )

            Divider().opacity(0.3)

            KumaTextField(
                label: usePattern ? "Target Pattern" : "Target Name",
                value: $targetName,
                placeholder: targetType.placeholder(usePattern: usePattern)
            )
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var context = "staging-k8s-cluster"
        @State private var ns = "backend"
        @State private var type = KubeTargetType.pod
        @State private var pattern = true
        @State private var target = "postgres-*"

        var body: some View {
            KumaFormSection(
                icon: "network",
                title: "Connection"
            ) {
                KubeClusterAndTargetSectionView(
                    kubeContext: $context,
                    kubeNamespace: $ns,
                    targetType: $type,
                    usePattern: $pattern,
                    targetName: $target
                )
            }
            .padding()
            .frame(width: 500)
            .background(KumaColors.canvasBackground)
        }
    }
    return PreviewWrapper()
}
