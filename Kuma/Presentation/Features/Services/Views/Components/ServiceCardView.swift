//
//  ServiceCardView.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% V3 Pixel-Perfect Service Card with Provider Badges, Status Toggles, and Port Mapping pills.
//

import SwiftUI
import AppKit

public struct ServiceCardView: View {
    public let service: Service
    public let providerCategory: ProviderCategory
    public let detailDescription: String
    public let portMappings: [ServicePortMapping]
    public let isSelected: Bool
    public let status: ServiceState
    public let isLoading: Bool

    public var onToggle: () -> Void
    public var onSelect: () -> Void

    @State private var isHovered = false
    @State private var isPortHovered: [Int: Bool] = [:]

    public init(
        service: Service,
        providerCategory: ProviderCategory = .docker,
        detailDescription: String = "",
        portMappings: [ServicePortMapping] = [],
        isSelected: Bool = false,
        status: ServiceState = .stopped,
        isLoading: Bool = false,
        onToggle: @escaping () -> Void = {},
        onSelect: @escaping () -> Void = {}
    ) {
        self.service = service
        self.providerCategory = providerCategory
        self.detailDescription = detailDescription
        self.portMappings = portMappings
        self.isSelected = isSelected
        self.status = status
        self.isLoading = isLoading
        self.onToggle = onToggle
        self.onSelect = onSelect
    }

    private var statusColor: Color {
        switch status {
        case .running:    return .green
        case .starting:   return .accentColor
        case .stopping:   return .orange
        case .crashed:    return .red
        case .degraded:   return .orange
        case .stopped:    return .secondary
        }
    }

    private var statusText: String {
        switch status {
        case .running:    return "running"
        case .starting:   return "starting"
        case .stopping:   return "stopping"
        case .crashed:    return "failed"
        case .degraded:   return "degraded"
        case .stopped:    return "stopped"
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Service Provider Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(providerCategory.color.gradient)
                        .frame(width: 34, height: 34)
                        .shadow(color: Color.black.opacity(0.04), radius: 1, y: 0.5)

                    Image(systemName: providerCategory.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(service.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(service.isDisabled ? .secondary : .primary)
                            .lineLimit(1)

                        if service.isDisabled {
                            Text("Disabled")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                    }

                    Text(detailDescription.isEmpty ? providerCategory.sidebarLabel : detailDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Native macOS Toggle Switch (100% V3 Match)
                if service.isDisabled {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                } else {
                    let isOnBinding = Binding<Bool>(
                        get: { status == .running || status == .starting },
                        set: { _ in onToggle() }
                    )
                    Toggle("", isOn: isOnBinding)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .disabled(isLoading || status == .starting || status == .stopping)
                }
            }

            // Port Mappings and Status Footprint
            if !portMappings.isEmpty || status != .stopped {
                HStack(spacing: 6) {
                    if !portMappings.isEmpty {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)

                        // Clickable Port Chips
                        HStack(spacing: 4) {
                            ForEach(portMappings) { mapping in
                                let port = mapping.localPort
                                Button {
                                    if let url = URL(string: "http://localhost:\(port)") {
                                        NSWorkspace.shared.open(url)
                                    }
                                } label: {
                                    HStack(spacing: 3) {
                                        Text("\(port)")
                                            .font(.system(size: 10, design: .monospaced))
                                        if isPortHovered[port] == true {
                                            Image(systemName: "link")
                                                .font(.system(size: 8))
                                        }
                                    }
                                    .foregroundStyle(isPortHovered[port] == true ? Color.accentColor : Color.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(isPortHovered[port] == true ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    isPortHovered[port] = hovering
                                }
                            }
                        }
                    }

                    Spacer()

                    StatusPillView(
                        text: statusText,
                        color: statusColor,
                        showDot: true,
                        isGlowing: status == .running,
                        isLoading: status == .starting || status == .stopping
                    )
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .background(Color.primary.opacity(isHovered ? 0.02 : 0.0))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.8) : (isHovered ? Color.primary.opacity(0.15) : Color.primary.opacity(0.06)),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .shadow(color: .black.opacity(isSelected ? 0.05 : 0.02), radius: isSelected ? 6 : 2, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
