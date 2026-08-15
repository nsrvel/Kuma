//
//  ServiceTableView.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% V3 Pixel-Perfect Table View for Services Deck.
//

import SwiftUI

public struct ServiceTableView: View {
    public let services: [Service]
    public let portMappings: [UUID: [ServicePortMapping]]
    public let selectedID: UUID?
    public let states: [UUID: ServiceState]
    public let loadingIDs: Set<UUID>

    public var onToggle: (Service) -> Void
    public var onSelect: (Service) -> Void

    @State private var selection: Set<UUID> = []

    public init(
        services: [Service],
        portMappings: [UUID: [ServicePortMapping]],
        selectedID: UUID?,
        states: [UUID: ServiceState],
        loadingIDs: Set<UUID>,
        onToggle: @escaping (Service) -> Void,
        onSelect: @escaping (Service) -> Void
    ) {
        self.services = services
        self.portMappings = portMappings
        self.selectedID = selectedID
        self.states = states
        self.loadingIDs = loadingIDs
        self.onToggle = onToggle
        self.onSelect = onSelect
    }

    public var body: some View {
        Table(services, selection: $selection) {
            TableColumn("Name") { service in
                let status = states[service.id] ?? .stopped
                let isLoading = loadingIDs.contains(service.id)

                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.gradient)
                            .frame(width: 24, height: 24)
                            .shadow(color: Color.black.opacity(0.06), radius: 1, y: 0.5)

                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)
                            .symbolEffect(.pulse, isActive: isLoading || status == .starting)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 6) {
                            Text(service.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.primary)

                            if service.isDisabled {
                                Text("disabled")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.primary.opacity(0.06), in: Capsule())
                            }
                        }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelect(service) }
            }

            TableColumn("Configuration") { service in
                Text(service.description ?? "Docker: postgres:16-alpine")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .onTapGesture { onSelect(service) }
            }

            TableColumn("Ports") { service in
                let ports = portMappings[service.id] ?? []
                ScrollView(.horizontal, showsIndicators: false) {
                    PortChipsView(ports: ports.map { "\($0.localPort):\($0.remotePort)" }, limit: 4)
                        .padding(.vertical, 2)
                }
            }

            TableColumn("Status") { service in
                let state = states[service.id] ?? .stopped

                let statusColor: Color = {
                    if service.isDisabled { return .secondary }
                    switch state {
                    case .running:    return .green
                    case .crashed:    return .red
                    case .starting:   return .accentColor
                    case .stopping:   return .orange
                    default:          return .secondary
                    }
                }()

                let statusText: String = {
                    if service.isDisabled { return "disabled" }
                    switch state {
                    case .running:    return "running"
                    case .crashed:    return "failed"
                    case .starting:   return "starting"
                    case .stopping:   return "stopping"
                    default:          return "stopped"
                    }
                }()

                StatusPillView(
                    text: statusText,
                    color: statusColor,
                    showDot: true,
                    isGlowing: state == .running,
                    isLoading: state == .starting || state == .stopping
                )
                .onTapGesture { onSelect(service) }
            }

            TableColumn("") { service in
                let status = states[service.id] ?? .stopped
                let isLoading = loadingIDs.contains(service.id)

                let isOnBinding = Binding<Bool>(
                    get: { status == .running || status == .starting },
                    set: { _ in onToggle(service) }
                )

                Toggle("", isOn: isOnBinding)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .disabled(service.isDisabled || isLoading)
            }
            .width(44)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .onChange(of: selection) { _, new in
            if let id = new.first, id != selectedID, let service = services.first(where: { $0.id == id }) {
                onSelect(service)
            }
        }
        .onChange(of: selectedID) { _, id in
            if let id { selection = [id] } else { selection = [] }
        }
        .onAppear {
            if let selectedID { selection = [selectedID] }
        }
    }
}
