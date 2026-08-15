import SwiftUI
import UniformTypeIdentifiers

public struct SettingsTunnelingToolsSection: View {
    @Bindable var store: SettingsStore

    // Auto-detected default paths when custom path is empty
    @State private var defaultCloudflaredPath: String = ""
    @State private var defaultNgrokPath: String = ""

    public init(store: SettingsStore) {
        self.store = store
    }

    // MARK: - Validation Computations (Zero-latency)

    private var cloudflaredValidation: BinaryValidationResult {
        DependencyChecker.validateCustomBinary(path: store.cloudflaredPath, expectedCommand: "cloudflared")
    }

    private var isCloudflaredAvailable: Bool {
        if store.cloudflaredPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return !defaultCloudflaredPath.isEmpty
        }
        return cloudflaredValidation.isValid
    }

    private var ngrokValidation: BinaryValidationResult {
        DependencyChecker.validateCustomBinary(path: store.customNgrokPath, expectedCommand: "ngrok")
    }

    private var isNgrokAvailable: Bool {
        if store.customNgrokPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return !defaultNgrokPath.isEmpty
        }
        return ngrokValidation.isValid
    }

    public var body: some View {
        KumaFormSection(
            icon: "cloud.bolt.fill",
            title: "Tunneling Tools"
        ) {
            VStack(alignment: .leading, spacing: KumaSpacing.lg) {
                // Cloudflare Tunnel
                VStack(alignment: .leading) {
                    HStack {
                        Text("Cloudflare Tunnel Binary (cloudflared)")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        statusBadge(isInstalled: isCloudflaredAvailable)
                    }
                    KumaFilePickerField(
                        label: "",
                        path: $store.cloudflaredPath,
                        placeholder: defaultCloudflaredPath.isEmpty ? "/opt/homebrew/bin/cloudflared" : defaultCloudflaredPath,
                        chooseFiles: true,
                        chooseDirectories: false,
                        allowedContentTypes: [.unixExecutable, .executable],
                        error: cloudflaredValidation.errorMessage
                    )
                }

                Divider().opacity(0.3)

                // ngrok Tunnel
                VStack(alignment: .leading) {
                    HStack {
                        Text("ngrok Binary")
                            .font(KumaFont.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        statusBadge(isInstalled: isNgrokAvailable)
                    }
                    KumaFilePickerField(
                        label: "",
                        path: $store.customNgrokPath,
                        placeholder: defaultNgrokPath.isEmpty ? "/opt/homebrew/bin/ngrok" : defaultNgrokPath,
                        chooseFiles: true,
                        chooseDirectories: false,
                        allowedContentTypes: [.unixExecutable, .executable],
                        error: ngrokValidation.errorMessage
                    )
                }
            }
        }
        .task {
            await refreshTunnelPaths()
        }
    }

    @ViewBuilder
    private func statusBadge(isInstalled: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isInstalled ? Color.green : Color.red.opacity(0.8))
                .frame(width: 6, height: 6)
            Text(isInstalled ? "Available" : "Not Found")
                .font(KumaFont.caption)
                .foregroundStyle(isInstalled ? Color.secondary : Color.red.opacity(0.8))
        }
    }

    private func refreshTunnelPaths() async {
        let resolver = EnvironmentPathResolver.shared
        let cf = await resolver.resolveExecutablePath(for: "cloudflared")
        let ng = await resolver.resolveExecutablePath(for: "ngrok")
        await MainActor.run {
            self.defaultCloudflaredPath = cf ?? ""
            self.defaultNgrokPath = ng ?? ""
        }
    }
}
