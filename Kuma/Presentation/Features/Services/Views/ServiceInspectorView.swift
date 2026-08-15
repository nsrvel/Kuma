//
//  ServiceInspectorView.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Right Inspector panel displaying service properties, configurations, port manager, and live terminal logs.
//

import SwiftUI

public struct ServiceInspectorView: View {
    public let serviceID: UUID
    public let workspaceID: UUID
    @Bindable var viewModel: ServicesDeckViewModel

    @State private var selectedTab: Int = 0

    public init(
        serviceID: UUID,
        workspaceID: UUID,
        viewModel: ServicesDeckViewModel
    ) {
        self.serviceID = serviceID
        self.workspaceID = workspaceID
        self.viewModel = viewModel
    }

    private var service: Service? {
        viewModel.services.first(where: { $0.id == serviceID })
    }

    private var status: ServiceState {
        viewModel.serviceStates[serviceID] ?? .stopped
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let service {
                // Inspector Header
                VStack(alignment: .leading, spacing: KumaSpacing.md) {
                    HStack(spacing: KumaSpacing.sm) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(service.name)
                                .font(KumaFont.bodyBold)
                                .lineLimit(1)

                            HStack(spacing: 4) {
                                Circle()
                                    .fill(status.color)
                                    .frame(width: 6, height: 6)
                                Text(status.title)
                                    .font(KumaFont.caption)
                                    .foregroundStyle(status.color)
                            }
                        }

                        Spacer()

                        // Action Controls
                        Button(action: { viewModel.toggleService(service) }) {
                            Image(systemName: status.isOperational ? "stop.fill" : "play.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(status.isOperational ? Color.red : Color.green)
                                .padding(6)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.6), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    // Segmented Tabs (Config / Ports / Logs)
                    Picker("", selection: $selectedTab) {
                        Text("Config").tag(0)
                        Text("Ports").tag(1)
                        Text("Logs").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(KumaSpacing.md)
                .background(.ultraThinMaterial)

                Divider()

                // Tab Content Area
                ScrollView {
                    VStack(alignment: .leading, spacing: KumaSpacing.lg) {
                        if selectedTab == 0 {
                            configSection(service: service)
                        } else if selectedTab == 1 {
                            portsSection(service: service)
                        } else {
                            logsSection(service: service)
                        }
                    }
                    .padding(KumaSpacing.md)
                }
            } else {
                KumaEmptyStateView(
                    iconName: "sidebar.right",
                    title: "No Selection",
                    description: "Select a service from the deck to view its inspector details."
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func configSection(service: Service) -> some View {
        KumaFormSection(icon: "slider.horizontal.3", title: "Service Configuration") {
            VStack(alignment: .leading, spacing: KumaSpacing.sm) {
                Text("Target Engine")
                    .font(KumaFont.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Image(systemName: "shippingbox.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("Docker Container")
                        .font(KumaFont.bodyMedium)
                }
                .padding(KumaSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: KumaRadius.sm))

                if let desc = service.description {
                    Text("Description")
                        .font(KumaFont.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    Text(desc)
                        .font(KumaFont.caption)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    @ViewBuilder
    private func portsSection(service: Service) -> some View {
        let ports = viewModel.portMappings[service.id] ?? []

        KumaFormSection(icon: "point.3.connected.trianglepath.dotted", title: "Port Forwarding") {
            VStack(alignment: .leading, spacing: KumaSpacing.sm) {
                if ports.isEmpty {
                    Text("No port mappings configured for this service.")
                        .font(KumaFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ports) { port in
                        HStack {
                            Text("Local \(port.localPort)")
                                .font(KumaFont.bodyMedium)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text("Remote \(port.remotePort)")
                                .font(KumaFont.bodyMedium)
                            Spacer()
                            Text(port.protocolType)
                                .font(KumaFont.captionBold)
                                .foregroundStyle(.secondary)
                        }
                        .padding(KumaSpacing.sm)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.45), in: RoundedRectangle(cornerRadius: KumaRadius.sm))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func logsSection(service: Service) -> some View {
        VStack(alignment: .leading, spacing: KumaSpacing.xs) {
            HStack {
                Text("Live Terminal Output")
                    .font(KumaFont.captionBold)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") {}
                    .buttonStyle(.plain)
                    .font(KumaFont.caption)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("[INFO] Service instance initialized")
                Text("[INFO] Binding socket listener to 127.0.0.1...")
                Text("[SUCCESS] Ready to accept incoming connections.")
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Color.green.opacity(0.9))
            .padding(KumaSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: KumaRadius.sm))
        }
    }
}

#Preview {
    let vm = ServicesDeckViewModel()
    let wid = UUID()
    vm.loadWorkspace(workspaceID: wid)
    let firstID = vm.services.first!.id

    return ServiceInspectorView(
        serviceID: firstID,
        workspaceID: wid,
        viewModel: vm
    )
    .frame(width: 400, height: 600)
}
