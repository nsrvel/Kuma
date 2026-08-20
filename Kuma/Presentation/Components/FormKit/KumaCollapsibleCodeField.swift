import SwiftUI
import AppKit

// MARK: - KumaCollapsibleCodeField

/// A specialized monospaced code editor with collapsible privacy blur and 2-space tab indentation.
public struct KumaCollapsibleCodeField: View {
    public let label: String
    @Binding public var value: String
    public var placeholder: String
    public var height: CGFloat
    public var configureActionTitle: String
    public var revealActionTitle: String
    public var iconName: String

    @State private var isExpanded: Bool = false
    @FocusState private var isFocused: Bool

    public init(
        label: String = "",
        value: Binding<String>,
        placeholder: String = "",
        height: CGFloat = 140,
        configureActionTitle: String = "Configure Code",
        revealActionTitle: String = "Reveal Code",
        iconName: String = "doc.text.fill"
    ) {
        self.label = label
        self._value = value
        self.placeholder = placeholder
        self.height = height
        self.configureActionTitle = configureActionTitle
        self.revealActionTitle = revealActionTitle
        self.iconName = iconName
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: KumaSpacing.xs) {
            // Header with label and Hide toggle
            if !label.isEmpty || isExpanded {
                HStack {
                    if !label.isEmpty {
                        Text(label)
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isExpanded {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                isExpanded = false
                            }
                        } label: {
                            Text("Hide")
                                .font(KumaFont.caption.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Editor Container with Blur & Action Capsule
            ZStack(alignment: .center) {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $value)
                        .font(.system(.body, design: .monospaced))
                        .focused($isFocused)
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.hidden)
                        .background(Color.clear)
                        .frame(height: isExpanded ? height : 64)
                        .onKeyPress(.tab) {
                            // Insert 2 spaces for standard YAML/Shell indentation
                            value.append("  ")
                            return .handled
                        }

                    // Monospaced Placeholder
                    if value.isEmpty {
                        Text(placeholder)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color(nsColor: .placeholderTextColor))
                            .padding(.leading, 5)
                            .padding(.top, 1)
                            .allowsHitTesting(false)
                    }
                }
                .padding(KumaSpacing.sm)
                .background(KumaColors.inputBackground, in: RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous)
                        .stroke(
                            isFocused ? Color.accentColor : KumaColors.inputBorder,
                            lineWidth: isFocused ? 1.5 : 0.5
                        )
                )
                .blur(radius: isExpanded ? 0 : 5)
                .opacity(isExpanded ? 1.0 : 0.7)
                .disabled(!isExpanded)

                // Privacy Mask Overlay
                if !isExpanded {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                isExpanded = true
                            }
                        }

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            isExpanded = true
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: value.isEmpty ? "plus.circle.fill" : "eye.fill")
                            Text(value.isEmpty ? configureActionTitle : revealActionTitle)
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(.regularMaterial, in: Capsule())
                        .overlay(Capsule().stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
                        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var composeEmpty = ""
        @State private var composeFilled = "version: '3.8'\nservices:\n  redis:\n    image: redis:alpine\n    ports:\n      - \"6379:6379\""

        var body: some View {
            VStack(spacing: 20) {
                KumaCollapsibleCodeField(
                    label: "Docker Compose (Empty)",
                    value: $composeEmpty,
                    placeholder: "version: '3.8'\nservices:\n  app:\n    image: nginx:alpine",
                    configureActionTitle: "Configure Compose YAML",
                    revealActionTitle: "Reveal Compose YAML"
                )

                KumaCollapsibleCodeField(
                    label: "Docker Compose (Filled)",
                    value: $composeFilled,
                    configureActionTitle: "Configure Compose YAML",
                    revealActionTitle: "Reveal Compose YAML"
                )
            }
            .padding()
            .frame(width: 480)
            .background(KumaColors.canvasBackground)
        }
    }
    return PreviewWrapper()
}
