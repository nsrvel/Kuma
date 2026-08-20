import SwiftUI

public struct ServiceGeneralSettingsView: View {
    @Binding public var name: String
    @Binding public var serviceDescription: String
    public let placeholder: String

    public init(
        name: Binding<String>,
        serviceDescription: Binding<String>,
        placeholder: String
    ) {
        self._name = name
        self._serviceDescription = serviceDescription
        self.placeholder = placeholder
    }

    public var body: some View {
        KumaFormSection(
            icon: "info.circle",
            title: "General"
        ) {
            VStack(alignment: .leading, spacing: 14) {
                KumaTextField(
                    label: "Service Name",
                    value: $name,
                    placeholder: placeholder
                )

                KumaTextArea(
                    label: "Description (Optional)",
                    value: $serviceDescription,
                    placeholder: "Service purpose or notes...",
                    minHeight: 60
                )
            }
        }
    }
}
