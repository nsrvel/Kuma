import SwiftUI
import AppKit
import UniformTypeIdentifiers

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
    @State private var previewImage: NSImage? = nil
    @State private var errorMessage: String? = nil
    @State private var isHoveringAvatar = false
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
                    avatarPickerSection

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
                                showDeleteAlert = true
                            } label: {
                                Text("Delete...")
                                    .foregroundStyle(Color.red)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
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
        .frame(minHeight: mode == .create ? 300 : 400)
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
        .onAppear {
            if case .edit(let ws) = mode, let imgPath = ws.imagePath {
                DispatchQueue.global(qos: .userInitiated).async {
                    if let nsImg = NSImage(contentsOfFile: imgPath) {
                        DispatchQueue.main.async {
                            self.previewImage = nsImg
                        }
                    }
                }
            }
        }
    }

    private var avatarPickerSection: some View {
        VStack(spacing: 8) {
            Button(action: selectImage) {
                ZStack {
                    WorkspaceAvatarView(
                        name: name.isEmpty ? "Workspace" : name,
                        imagePath: selectedImagePath,
                        size: 80
                    )

                    // Hover Action Overlay
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(isHoveringAvatar ? 0.4 : 0.0))
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white)
                                .opacity(isHoveringAvatar ? 1.0 : 0.0)
                        )
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 4, y: 2)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHoveringAvatar = hovering
                }
            }

            HStack(spacing: 8) {
                if previewImage != nil || selectedImagePath != nil {
                    Button(action: {
                        selectedImagePath = nil
                        previewImage = nil
                    }) {
                        Text("Remove Photo")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: selectImage) {
                        Text("Choose Photo")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @State private var selectedImageURL: URL? = nil

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK, let url = panel.url {
            self.selectedImageURL = url
            self.selectedImagePath = url.path
            self.previewImage = NSImage(contentsOfFile: url.path)
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
            let newWS = store.addWorkspace(name: trimmedName, imagePath: selectedImageURL?.path ?? selectedImagePath)
            store.selectWorkspace(newWS)
        case .edit(var ws):
            ws.name = trimmedName
            if selectedImagePath == nil {
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
