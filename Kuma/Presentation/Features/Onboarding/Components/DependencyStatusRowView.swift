//
//  DependencyStatusRowView.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Reusable card row showing status, icon, and path of a CLI dependency.
//

import SwiftUI
import UniformTypeIdentifiers

public struct DependencyStatusRowView: View {
    let dependency: SystemDependency
    var isScanning: Bool = false
    var onBrowse: ((String) -> Void)? = nil

    @State private var isFileImporterPresented = false
    @State private var isHovering = false

    public init(
        dependency: SystemDependency,
        isScanning: Bool = false,
        onBrowse: ((String) -> Void)? = nil
    ) {
        self.dependency = dependency
        self.isScanning = isScanning
        self.onBrowse = onBrowse
    }

    private var allowedContentTypes: [UTType] {
        if dependency.id == "kubeconfig" {
            var types: [UTType] = [.plainText]
            if let yamlType = UTType(filenameExtension: "yaml") { types.append(yamlType) }
            if let ymlType = UTType(filenameExtension: "yml") { types.append(ymlType) }
            return types
        }
        return [.unixExecutable, .executable]
    }

    public var body: some View {
        KumaCard(padding: KumaSpacing.md) {
            HStack(spacing: KumaSpacing.md) {
                // Icon Container
                Image(systemName: dependency.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(dependency.isInstalled ? .primary : .secondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(dependency.isInstalled ? Color.primary.opacity(0.1) : Color.primary.opacity(0.04))
                    )

                // Info Column
                VStack(alignment: .leading, spacing: 2) {
                    Text(dependency.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    if isScanning {
                        Text("Checking PATH…")
                            .font(KumaFont.subheadline)
                            .foregroundStyle(.secondary)
                    } else if dependency.isInstalled {
                        if let path = dependency.path {
                            Text(path)
                                .font(KumaFont.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        } else {
                            Text("Installed")
                                .font(KumaFont.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Not Found")
                            .font(KumaFont.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: KumaSpacing.sm)

                // Status Indicator or Action Button
                if isScanning {
                    ProgressView()
                        .controlSize(.small)
                } else if dependency.isInstalled {
                    KumaStatusBadge(.available)
                } else if onBrowse != nil {
                    Button("Browse…") {
                        isFileImporterPresented = true
                    }
                    .font(KumaFont.subheadline)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: allowedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let selectedURL = urls.first {
                onBrowse?(selectedURL.path)
            }
        }
    }
}

#Preview("Available") {
    DependencyStatusRowView(
        dependency: SystemDependency(
            id: "docker",
            name: "Docker Engine & Compose",
            iconName: "shippingbox.fill",
            isInstalled: true,
            path: "/opt/homebrew/bin/docker"
        )
    )
    .padding()
}

#Preview("Not Found") {
    DependencyStatusRowView(
        dependency: SystemDependency(
            id: "podman",
            name: "Podman Engine",
            iconName: "cylinder.split.1x2.fill",
            isInstalled: false
        ),
        onBrowse: { _ in }
    )
    .padding()
}
