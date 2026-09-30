import SwiftUI

public struct ServiceProvidersInlineFormView: View {
    public let isEditing: Bool
    @Binding public var formType: ProviderCategory
    @Binding public var formLabel: String
    public let onSave: () -> Void
    public let onCancel: () -> Void

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    isEditing ? "Edit Provider" : "New Provider",
                    systemImage: "square.stack.3d.down.right.fill"
                )
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)

            KumaRowPickerField(
                label: "Provider Type",
                description: "Select runtime engine.",
                options: ProviderCategory.allCases.map(\.rawValue),
                selection: Binding(
                    get: { formType.rawValue },
                    set: { if let cat = ProviderCategory(rawValue: $0) { formType = cat } }
                ),
                titleResolver: { (ProviderCategory(rawValue: $0) ?? .docker).sidebarLabel }
            )

            Divider().opacity(0.4)

            KumaTextField(
                label: "Custom Label (Optional)",
                value: $formLabel,
                placeholder: "Staging"
            )

            HStack {
                Spacer()
                Button("Save") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(Color.primary.opacity(0.02))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}
