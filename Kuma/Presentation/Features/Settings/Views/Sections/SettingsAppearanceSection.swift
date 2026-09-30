import SwiftUI

public struct SettingsAppearanceSection: View {
    @Bindable var viewModel: SettingsViewModel
    @Namespace private var selectionNamespace

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        KumaFormSection(
            icon: "paintbrush.fill",
            title: "Appearance"
        ) {
            VStack(alignment: .leading, spacing: KumaSpacing.lg) {
                Text("Choose how Kuma looks. Select a theme or let it follow your system setting.")
                    .font(KumaFont.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: KumaSpacing.md) {
                    ForEach(KumaAppearance.allCases, id: \.self) { mode in
                        AppearanceCard(
                            mode: mode,
                            isSelected: viewModel.appearance == mode,
                            namespace: selectionNamespace,
                            onSelect: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                    viewModel.appearance = mode
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsAppearanceSection(viewModel: SettingsViewModel())
        .padding()
        .frame(width: 600)
}

