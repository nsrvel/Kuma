import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - WorkspaceAvatarPickerView

public struct WorkspaceAvatarPickerView: View {
    public let name: String
    @Binding public var selectedImagePath: String?
    @Binding public var selectedImageURL: URL?

    @State private var isHoveringAvatar = false

    public init(
        name: String,
        selectedImagePath: Binding<String?>,
        selectedImageURL: Binding<URL?>
    ) {
        self.name = name
        self._selectedImagePath = selectedImagePath
        self._selectedImageURL = selectedImageURL
    }

    public var body: some View {
        VStack(spacing: 8) {
            Button(action: selectImage) {
                ZStack {
                    WorkspaceAvatarView(
                        name: name.isEmpty ? "Workspace" : name,
                        imagePath: selectedImageURL?.path(percentEncoded: false) ?? selectedImagePath,
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
                if selectedImageURL != nil || selectedImagePath != nil {
                    Button(action: {
                        selectedImagePath = nil
                        selectedImageURL = nil
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

    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        if panel.runModal() == .OK, let url = panel.url {
            self.selectedImageURL = url
            self.selectedImagePath = url.path(percentEncoded: false)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var path: String? = nil
        @State private var url: URL? = nil
        var body: some View {
            WorkspaceAvatarPickerView(name: "Production Backend", selectedImagePath: $path, selectedImageURL: $url)
                .padding()
        }
    }
    return PreviewWrapper()
}
