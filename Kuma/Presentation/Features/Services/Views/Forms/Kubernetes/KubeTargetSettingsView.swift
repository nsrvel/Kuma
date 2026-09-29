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

    private var showsStableWorkloadHint: Bool {
        guard targetType == .pod, !usePattern else { return false }
        let name = targetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        return KubeTargetNamingHints.looksLikeStableWorkloadName(name)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            KumaRowPickerField(
                label: "Target Type",
                description: "Resource kind for port-forward.",
                options: KubeTargetType.allCases,
                selection: $targetType,
                titleResolver: { $0.label }
            )

            Divider().opacity(0.3)

            KumaToggleField(
                label: "Pattern Matching",
                value: $usePattern,
                description: "Match names with * wildcards."
            )

            Divider().opacity(0.3)

            KumaTextField(
                label: "Target Name",
                value: $targetName,
                placeholder: targetType.placeholder(usePattern: usePattern)
            )

            if showsStableWorkloadHint {
                Text("Try Deployment or Service as target type if start fails.")
                    .font(KumaFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
