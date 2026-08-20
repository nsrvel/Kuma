import SwiftUI

/// Scrollable middle zone of the Service Inspector.
/// Renders contextual key-value configuration per provider type,
/// active port mappings, and service metadata in grouped card sections.
public struct InspectorDetailRows: View {
    public let data: InspectorData

    public init(data: InspectorData) {
        self.data = data
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KumaSpacing.lg) {
                // Section 1: Configuration
                inspectorSection("CONFIGURATION", icon: "gearshape.fill") {
                    providerConfigRows
                }

                // Section 2: Port Mappings
                if !data.portMappings.isEmpty {
                    inspectorSection("PORT MAPPINGS", icon: "arrow.left.arrow.right") {
                        ForEach(data.portMappings) { mapping in
                            portRow(mapping)
                        }
                    }
                }

                // Section 3: Metadata
                inspectorSection("METADATA", icon: "info.circle.fill") {
                    if let desc = data.service.description, !desc.isEmpty {
                        InspectorKeyValueRow(key: "Description", value: desc)
                    }
                    InspectorKeyValueRow(key: "Created", value: data.service.createdAt.formatted(date: .abbreviated, time: .omitted))
                    InspectorKeyValueRow(key: "Updated", value: relativeUpdated)
                }
            }
            .padding(KumaSpacing.lg)
        }
    }

    // MARK: - Grouped Card Section

    @ViewBuilder
    private func inspectorSection<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: KumaSpacing.sm) {
            // Section header
            HStack(spacing: KumaSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, KumaSpacing.xs)

            // Card surface
            VStack(alignment: .leading, spacing: 0) {
                content()
                    .padding(.horizontal, KumaSpacing.md)
                    .padding(.vertical, KumaSpacing.sm)
            }
            .background(KumaColors.surfaceBackground, in: RoundedRectangle(cornerRadius: KumaRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: KumaRadius.md, style: .continuous)
                    .strokeBorder(KumaColors.borderSubtle.opacity(0.5), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Port Mapping Row

    @ViewBuilder
    private func portRow(_ mapping: ServicePortMapping) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 5, height: 5)

            Text("localhost:\(mapping.localPort)")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.primary)

            Image(systemName: "arrow.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)

            Text("\(mapping.remotePort)/\(mapping.protocolType)")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Provider Config Rows (Contextual Switch)

    @ViewBuilder
    private var providerConfigRows: some View {
        let p = data.provider
        switch p.type {
        case .kubernetes:
            kubernetesRows(p)
        case .docker, .podman:
            composeRows(p)
        case .shell:
            shellRows(p)
        case .ssh:
            sshRows(p)
        case .httpCheck:
            healthCheckRows(p)
        case .tunnel:
            tunnelRows(p)
        case .processMonitor:
            processMonitorRows(p)
        }
    }

    @ViewBuilder
    private func kubernetesRows(_ p: Provider) -> some View {
        InspectorKeyValueRow(key: "Target", value: p.targetName ?? "", isMonospaced: true)
        Divider().padding(.vertical, 2)
        InspectorKeyValueRow(key: "Type", value: (p.kubeTargetType ?? "pod").capitalized, isBadge: true, badgeColor: .blue)
        Divider().padding(.vertical, 2)
        InspectorKeyValueRow(key: "Namespace", value: p.kubeNamespace ?? "default")
        if let ctx = p.kubeContext, !ctx.isEmpty {
            Divider().padding(.vertical, 2)
            InspectorKeyValueRow(key: "Context", value: ctx)
        }
        Divider().padding(.vertical, 2)
        InspectorKeyValueRow(key: "Match", value: (p.usePattern ?? true) ? "Pattern (Prefix)" : "Exact Name")
    }

    @ViewBuilder
    private func composeRows(_ p: Provider) -> some View {
        InspectorKeyValueRow(key: "Image", value: p.resolvedTarget, isMonospaced: true)
        Divider().padding(.vertical, 2)
        InspectorKeyValueRow(
            key: "Init Script",
            value: (p.initialScript?.isEmpty ?? true) ? "None" : "Configured",
            isBadge: true,
            badgeColor: (p.initialScript?.isEmpty ?? true) ? .secondary : .green
        )
    }

    @ViewBuilder
    private func shellRows(_ p: Provider) -> some View {
        InspectorKeyValueRow(key: "Command", value: p.runCommand ?? "", isMonospaced: true)
        if let cwd = p.workingDirectory, !cwd.isEmpty {
            Divider().padding(.vertical, 2)
            InspectorKeyValueRow(key: "Directory", value: cwd, isMonospaced: true)
        }
    }

    @ViewBuilder
    private func sshRows(_ p: Provider) -> some View {
        InspectorKeyValueRow(key: "Host", value: p.sshHost ?? "", isMonospaced: true)
        Divider().padding(.vertical, 2)
        InspectorKeyValueRow(key: "User", value: p.sshUser ?? "")
        Divider().padding(.vertical, 2)
        InspectorKeyValueRow(key: "Port", value: "\(p.sshPort ?? 22)", isMonospaced: true)
        Divider().padding(.vertical, 2)
        InspectorKeyValueRow(
            key: "Auth",
            value: (p.sshPassword?.isEmpty ?? true) ? "SSH Key" : "Password",
            isBadge: true,
            badgeColor: .purple
        )
    }

    @ViewBuilder
    private func healthCheckRows(_ p: Provider) -> some View {
        InspectorKeyValueRow(key: "Target URL", value: p.httpCheckUrl ?? "", isMonospaced: true)
        Divider().padding(.vertical, 2)
        InspectorKeyValueRow(key: "Interval", value: "\(p.httpCheckInterval ?? 5)s")
    }

    @ViewBuilder
    private func tunnelRows(_ p: Provider) -> some View {
        InspectorKeyValueRow(
            key: "Engine",
            value: p.tunnelType == "ngrok" ? "Ngrok" : "Cloudflare",
            isBadge: true,
            badgeColor: .orange
        )
        Divider().padding(.vertical, 2)
        InspectorKeyValueRow(key: "Target", value: p.tunnelTargetUrl ?? "", isMonospaced: true)
        if p.tunnelType == "ngrok" {
            Divider().padding(.vertical, 2)
            InspectorKeyValueRow(
                key: "Auth Token",
                value: (p.ngrokAuthToken?.isEmpty ?? true) ? "Not set" : "••••••••",
                isBadge: !(p.ngrokAuthToken?.isEmpty ?? true),
                badgeColor: .green
            )
        }
    }

    @ViewBuilder
    private func processMonitorRows(_ p: Provider) -> some View {
        InspectorKeyValueRow(key: "Process", value: p.monitorProcessName ?? "", isMonospaced: true)
        Divider().padding(.vertical, 2)
        InspectorKeyValueRow(key: "Interval", value: "\(p.monitorInterval ?? 5)s")
    }

    // MARK: - Relative Date

    private var relativeUpdated: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: data.service.updatedAt, relativeTo: Date())
    }
}
