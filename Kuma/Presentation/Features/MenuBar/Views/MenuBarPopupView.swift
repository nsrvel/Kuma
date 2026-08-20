import SwiftUI

/// Main Content View for the macOS MenuBar Extra Popover.
/// Lists running/starred services, provides Start All / Stop All bulk actions, and quick navigation.
public struct MenuBarPopupView: View {
    @Environment(WorkspaceStore.self) private var workspaceStore
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow

    @State private var snapshots: [ServiceCardSnapshot] = []
    @State private var runningStates: [UUID: Bool] = [:]

    private let serviceRepository: any ServiceRepositoryProtocol

    public init(serviceRepository: any ServiceRepositoryProtocol = ServiceRepository()) {
        self.serviceRepository = serviceRepository
    }

    private var activeCount: Int {
        runningStates.values.filter { $0 }.count
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Header: Workspace Status & Open Main Window
            MenuBarHeaderView(
                workspaceName: workspaceStore.activeWorkspace?.name ?? "Kuma",
                activeCount: activeCount,
                totalCount: snapshots.count,
                onOpenMainWindow: {
                    openWindow(id: "main-workspace")
                    NSApp.activate(ignoringOtherApps: true)
                }
            )

            Divider().opacity(0.5)

            // 2. Services List
            if snapshots.isEmpty {
                VStack(spacing: 6) {
                    Text("No services in workspace")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(snapshots) { snap in
                            MenuBarServiceSnapshotRowView(
                                snapshot: snap,
                                isRunning: runningStates[snap.id] ?? false,
                                onToggle: {
                                    let current = runningStates[snap.id] ?? false
                                    runningStates[snap.id] = !current
                                }
                            )
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: 220)
            }

            Divider().opacity(0.5)

            // 3. Quick Bulk Actions & Utilities Footer
            HStack(spacing: 8) {
                Button {
                    for s in snapshots where !s.isDisabled {
                        runningStates[s.id] = true
                    }
                } label: {
                    Label("Start All", systemImage: "play.fill")
                        .font(.system(size: 10.5))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    for s in snapshots {
                        runningStates[s.id] = false
                    }
                } label: {
                    Label("Stop All", systemImage: "stop.fill")
                        .font(.system(size: 10.5))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit Kuma")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.02))
        }
        .frame(width: 280)
        .task(id: workspaceStore.activeWorkspace?.id) {
            await loadServices()
        }
    }

    private func loadServices() async {
        guard let wsID = workspaceStore.activeWorkspace?.id else { return }
        do {
            let snaps = try await serviceRepository.fetchSnapshots(forWorkspace: wsID)
            await MainActor.run {
                self.snapshots = snaps
            }
        } catch {}
    }
}

