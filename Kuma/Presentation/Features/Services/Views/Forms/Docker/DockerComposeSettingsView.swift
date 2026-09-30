import SwiftUI

// MARK: - DockerComposeSettingsView

/// Docker Compose YAML configuration editor with progressive disclosure inline expansion.
public struct DockerComposeSettingsView: View {
    @Binding public var yamlConfig: String
    public var isLocked: Bool
    public var onSave: () -> Void

    @State private var isExpanded: Bool = false
    @State private var draftYAML: String = ""

    public init(
        yamlConfig: Binding<String>,
        isLocked: Bool = false,
        onSave: @escaping () -> Void = {}
    ) {
        self._yamlConfig = yamlConfig
        self.isLocked = isLocked
        self.onSave = onSave
    }

    public var body: some View {
        Group {
            if !isExpanded {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Compose File")
                            .font(KumaFont.body)
                        Text(summaryText)
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Configure") {
                        draftYAML = yamlConfig
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            isExpanded = true
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Docker Compose (docker-compose.yml)", systemImage: "doc.text.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isExpanded = false
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    KumaCodeEditor(
                        code: $draftYAML,
                        placeholder: "version: '3.8'\nservices:\n  web:\n    image: nginx:alpine\n    ports:\n      - \"80:80\"",
                        minHeight: 160
                    )

                    HStack {
                        Button("Cancel") {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isExpanded = false
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer()

                        Button("Done") {
                            yamlConfig = draftYAML
                            onSave()
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                isExpanded = false
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
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
        .onChange(of: isLocked) { _, locked in
            if locked && isExpanded {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded = false
                }
            }
        }
    }

    private var summaryText: String {
        let trimmed = yamlConfig.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "No docker-compose.yml configured."
        }
        let lineCount = trimmed.components(separatedBy: .newlines).count
        return "\(lineCount) \(lineCount == 1 ? "line" : "lines") configured"
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var yaml = "version: '3.8'\nservices:\n  db:\n    image: postgres:15\n    environment:\n      POSTGRES_PASSWORD: secretpassword"

        var body: some View {
            KumaFormSection(
                icon: "shippingbox.fill",
                title: "Docker Compose"
            ) {
                DockerComposeSettingsView(yamlConfig: $yaml)
            }
            .padding()
            .frame(width: 500)
            .background(KumaColors.canvasBackground)
        }
    }
    return PreviewWrapper()
}
