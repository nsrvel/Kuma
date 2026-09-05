import SwiftUI
import AppKit

public enum WorkspaceFormMode: Equatable {
    case create
    case edit(Workspace)
}

public struct WorkspaceFormSheet: View {
    @Bindable var store: WorkspaceStore
    let mode: WorkspaceFormMode
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var selectedImagePath: String? = nil
    @State private var selectedImageURL: URL? = nil
    @State private var errorMessage: String? = nil
    @State private var showDeleteAlert = false

    public init(store: WorkspaceStore, mode: WorkspaceFormMode, isPresented: Binding<Bool>) {
        self.store = store
        self.mode = mode
        self._isPresented = isPresented

        switch mode {
        case .create:
            _name = State(initialValue: "")
        case .edit(let ws):
            _name = State(initialValue: ws.name)
            _selectedImagePath = State(initialValue: ws.imagePath)
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Dialog Header (Centered Title - Apple HIG macOS Standard)
            Text(mode == .create ? "New Workspace" : "Workspace Settings")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.primary)
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()
                .opacity(0.4)

            // 2. Form Body
            VStack(alignment: .leading, spacing: 20) {
                // Workspace Info (Avatar Picker & Name)
                VStack(spacing: 16) {
                    WorkspaceAvatarPickerView(
                        name: name.isEmpty ? "Workspace" : name,
                        selectedImagePath: $selectedImagePath,
                        selectedImageURL: $selectedImageURL
                    )

                    KumaTextField(
                        label: "Workspace Name",
                        value: $name,
                        placeholder: "My Workspace",
                        autoFocus: true,
                        onSubmit: {
                            if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                saveChanges()
                            }
                        }
                    )
                }
                .padding(.top, 8)

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.red)
                        .padding(.top, -8)
                }

                // Danger Zone / Delete Button (only if editing and >1 workspace)
                if case .edit = mode, store.workspaces.count > 1 {
                    dangerZoneSection
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()
                .opacity(0.4)

            // 3. Dialog Footer (Native macOS Bottom-Right Action Buttons)
            HStack(spacing: 12) {
                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button(mode == .create ? "Add" : "Save") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 440)
        .frame(minHeight: (mode == .create || store.workspaces.count <= 1) ? 300 : 400)
        .alert("Delete Workspace?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if case .edit(let ws) = mode {
                    store.deleteWorkspace(ws)
                    isPresented = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if case .edit(let ws) = mode {
                Text("All services and configurations in “\(ws.name)” will be permanently deleted. This action cannot be undone.")
            }
        }
    }

    private var dangerZoneSection: some View {
        KumaFormSection(icon: "exclamationmark.triangle", title: "Danger Zone", style: .danger) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.red.opacity(0.8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Delete Workspace")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Permanently remove this workspace and all configuration.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button(role: .destructive) {
                    if case .edit(let ws) = mode {
                        isPresented = false
                        AlertService.shared.confirmDelete(
                            title: "Delete Workspace?",
                            message: "All services and configurations in “\(ws.name)” will be permanently deleted. This action cannot be undone.",
                            confirmTitle: "Delete"
                        ) {
                            store.deleteWorkspace(ws)
                        }
                    }
                } label: {
                    Text("Delete...")
                        .foregroundStyle(Color.red)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func saveChanges() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Name cannot be empty"
            return
        }

        switch mode {
        case .create:
            let newWS = store.addWorkspace(name: trimmedName, imagePath: selectedImageURL?.path(percentEncoded: false) ?? selectedImagePath)
            store.selectWorkspace(newWS)
        case .edit(var ws):
            ws.name = trimmedName
            if selectedImagePath == nil && selectedImageURL == nil {
                // User removed photo
                if let oldPath = ws.imagePath {
                    WorkspaceImageStore.shared.deleteImage(for: oldPath)
                }
                ws.imagePath = nil
            }
            ws.updatedAt = Date()
            store.updateWorkspace(ws, newExternalImageURL: selectedImageURL)
        }
        isPresented = false
    }
}

#Preview {
    WorkspaceFormSheet(
        store: WorkspaceStore(),
        mode: .create,
        isPresented: .constant(true)
    )
}
