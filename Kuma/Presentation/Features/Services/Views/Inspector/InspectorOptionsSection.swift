import SwiftUI

public struct InspectorOptionsSection: View {
    @Binding public var isDisabled: Bool
    public let isRunning: Bool
    public let isEditing: Bool
    public let onDelete: () -> Void

    public init(
        isDisabled: Binding<Bool>,
        isRunning: Bool = false,
        isEditing: Bool = true,
        onDelete: @escaping () -> Void
    ) {
        self._isDisabled = isDisabled
        self.isRunning = isRunning
        self.isEditing = isEditing
        self.onDelete = onDelete
    }

    public var body: some View {
        KumaFormSection(
            icon: "gearshape.fill",
            title: "Options"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                // Disable Service
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Disable Service")
                            .font(KumaFont.body)
                        Text("Excluded from bulk actions.")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: $isDisabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .accessibilityLabel("Disable service")
                        .disabled(isRunning)
                }

                Divider().opacity(0.4)

                // Delete Service
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Delete Service")
                            .font(KumaFont.body)
                            .foregroundStyle(.red)
                        Text("Permanent removal.")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Delete") {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.small)
                    .disabled(isRunning)
                }
            }
        }
    }
}





