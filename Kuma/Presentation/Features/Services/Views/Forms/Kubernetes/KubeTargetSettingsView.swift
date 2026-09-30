import SwiftUI

public struct KubeTargetSettingsView: View {
    @Binding public var targetName: String
    @Binding public var targetType: KubeTargetType
    @Binding public var usePattern: Bool

    public init(
        targetName: Binding<String>,
        targetType: Binding<KubeTargetType>,
        usePattern: Binding<Bool>
    ) {
        self._targetName = targetName
        self._targetType = targetType
        self._usePattern = usePattern
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                label: "Target Name",
                value: $targetName,
                placeholder: targetType.placeholder(usePattern: usePattern)
            )
        }
    }
}
