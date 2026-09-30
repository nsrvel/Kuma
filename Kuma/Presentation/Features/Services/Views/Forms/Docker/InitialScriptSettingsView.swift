import SwiftUI

// MARK: - InitialScriptSettingsView

/// Pre-startup shell script editor with progressive disclosure inline expansion.
public struct InitialScriptSettingsView: View {
    @Binding public var initialScript: String
    public var isLocked: Bool
    public var onSave: () -> Void

    @State private var isExpanded: Bool = false
    @State private var draftScript: String = ""

    public init(
        initialScript: Binding<String>,
        isLocked: Bool = false,
        onSave: @escaping () -> Void = {}
    ) {
        self._initialScript = initialScript
        self.isLocked = isLocked
        self.onSave = onSave
    }

    public var body: some View {
        Group {
            if !isExpanded {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Startup Script")
                            .font(KumaFont.body)
                        Text(summaryText)
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Configure") {
                        draftScript = initialScript
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
                        Label("Startup Script (sh / bash)", systemImage: "terminal.fill")
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
                        code: $draftScript,
                        placeholder: "#!/bin/sh\necho 'Preparing database migrations...'\n# Add any pre-startup commands here",
                        minHeight: 140
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
                            initialScript = draftScript
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
        let trimmed = initialScript.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "No startup script configured."
        }
        let lineCount = trimmed.components(separatedBy: .newlines).count
        return "\(lineCount) \(lineCount == 1 ? "line" : "lines") configured"
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var script = "echo 'Running migrations...'\nnpx prisma migrate deploy"

        var body: some View {
            KumaFormSection(
                icon: "terminal.fill",
                title: "Initial Script"
            ) {
                InitialScriptSettingsView(initialScript: $script)
            }
            .padding()
            .frame(width: 500)
            .background(KumaColors.canvasBackground)
        }
    }
    return PreviewWrapper()
}
