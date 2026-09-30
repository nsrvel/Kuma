import SwiftUI

// MARK: - ImportDetailInspectorPane (Context-Aware Multi-Provider Inspector)

public struct ImportDetailInspectorPane: View {
    public let serviceName: String
    public let serviceDescription: String?
    public let provider: DataPortService.ExportProvider?
    public let portMappings: [DataPortService.ExportPortMapping]
    public let hasConflict: Bool

    public init(
        serviceName: String,
        serviceDescription: String? = nil,
        provider: DataPortService.ExportProvider?,
        portMappings: [DataPortService.ExportPortMapping],
        hasConflict: Bool = false
    ) {
        self.serviceName = serviceName
        self.serviceDescription = serviceDescription
        self.provider = provider
        self.portMappings = portMappings
        self.hasConflict = hasConflict
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Header: Provider Gradient Icon + Title & Conflict Status
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(providerCategory.gradient)
                            .frame(width: 32, height: 32)
                            .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)

                        Image(systemName: providerCategory.icon)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(serviceName)
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if hasConflict {
                            Text("Name exists in workspace (will auto-rename)")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.orange)
                        } else if let desc = serviceDescription, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        } else {
                            Text(providerCategory.sidebarLabel)
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Divider().opacity(0.3)

                // Section 1: Clean Provider Configuration
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONFIGURATION")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.secondary)

                    if let p = provider {
                        detailRow(title: "Type", value: providerCategory.sidebarLabel)

                        switch providerCategory {
                        case .docker, .podman:
                            let img = p.resolvedTarget
                            if img != providerCategory.sidebarLabel {
                                detailRow(title: "Image", value: img, isMono: true)
                            }
                            if let script = p.initialScript, !script.isEmpty {
                                detailRow(title: "Init Script", value: script, isMono: true)
                            }

                        case .kubernetes:
                            if let target = p.targetName, !target.isEmpty {
                                detailRow(title: "Target", value: target, isMono: true)
                            }
                            if let ns = p.kubeNamespace, !ns.isEmpty {
                                detailRow(title: "Namespace", value: ns)
                            }
                            if let ctx = p.kubeContext, !ctx.isEmpty {
                                detailRow(title: "Context", value: ctx)
                            }
                            if let targetType = p.kubeTargetType, !targetType.isEmpty {
                                detailRow(title: "Resource", value: targetType.capitalized)
                            }

                        case .shell:
                            if let cmd = p.runCommand, !cmd.isEmpty {
                                detailRow(title: "Command", value: cmd, isMono: true)
                            }
                            if let dir = p.workingDirectory, !dir.isEmpty {
                                detailRow(title: "Working Dir", value: dir, isMono: true)
                            }

                        case .ssh:
                            if let host = p.sshHost, !host.isEmpty {
                                detailRow(title: "Host", value: "\(p.sshUser ?? "root")@\(host):\(p.sshPort ?? 22)", isMono: true)
                            }
                            if let key = p.sshKeyPath, !key.isEmpty {
                                detailRow(title: "Identity Key", value: key, isMono: true)
                            }

                        case .httpCheck:
                            if let url = p.httpCheckUrl, !url.isEmpty {
                                detailRow(title: "Health URL", value: url, isMono: true)
                            }
                            if let interval = p.httpCheckInterval {
                                detailRow(title: "Interval", value: "\(interval)s")
                            }

                        case .tunnel:
                            if let target = p.tunnelTargetUrl, !target.isEmpty {
                                detailRow(title: "Forward Target", value: target, isMono: true)
                            }
                            if let tType = p.tunnelType, !tType.isEmpty {
                                detailRow(title: "Tunnel Provider", value: tType.capitalized)
                            }

                        case .processMonitor:
                            if let proc = p.monitorProcessName, !proc.isEmpty {
                                detailRow(title: "Process Name", value: proc, isMono: true)
                            }
                            if let interval = p.monitorInterval {
                                detailRow(title: "Interval", value: "\(interval)s")
                            }
                        }
                    }
                }

                // Section 2: Port Mappings (Matching Service Inspector style)
                if !portMappings.isEmpty {
                    Divider().opacity(0.3)

                    VStack(alignment: .leading, spacing: KumaSpacing.sm) {
                        // Section header
                        HStack(spacing: KumaSpacing.xs) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            Text("PORT MAPPINGS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.leading, KumaSpacing.xs)

                        // Card surface
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(portMappings.enumerated()), id: \.element.id) { index, port in
                                if index > 0 {
                                    Divider()
                                        .padding(.vertical, 3)
                                        .opacity(0.4)
                                }

                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 5, height: 5)

                                    Text("localhost:\(port.localPort)")
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundStyle(.primary)

                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundStyle(.tertiary)

                                    Text("\(port.remotePort)/TCP")
                                        .font(.system(size: 11.5, design: .monospaced))
                                        .foregroundStyle(.secondary)

                                    Spacer()
                                }
                                .padding(.vertical, 3)
                            }
                        }
                        .padding(.horizontal, KumaSpacing.md)
                        .padding(.vertical, KumaSpacing.sm)
                        .background(KumaColors.surfaceBackground, in: RoundedRectangle(cornerRadius: KumaRadius.md, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: KumaRadius.md, style: .continuous)
                                .strokeBorder(KumaColors.borderSubtle.opacity(0.5), lineWidth: 0.5)
                        }
                    }
                }


            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KumaColors.surfaceBackground.opacity(0.5))
    }

    private var providerCategory: ProviderCategory {
        provider?.category ?? .docker
    }

    @ViewBuilder
    private func detailRow(title: String, value: String, isMono: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)

            Text(value)
                .font(.system(size: 11, design: isMono ? .monospaced : .default))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
    }
}
