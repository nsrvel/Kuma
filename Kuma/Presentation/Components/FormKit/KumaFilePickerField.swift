import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - KumaFilePickerField

public struct KumaFilePickerField: View {
    public let label: String
    @Binding public var path: String
    public var placeholder: String
    public var chooseFiles: Bool
    public var chooseDirectories: Bool
    public var allowedContentTypes: [UTType]?
    public var showsHiddenFiles: Bool
    public var error: String?

    @FocusState private var isFocused: Bool

    public init(
        label: String,
        path: Binding<String>,
        placeholder: String = "",
        chooseFiles: Bool = true,
        chooseDirectories: Bool = false,
        allowedContentTypes: [UTType]? = nil,
        showsHiddenFiles: Bool = true,
        error: String? = nil
    ) {
        self.label = label
        self._path = path
        self.placeholder = placeholder
        self.chooseFiles = chooseFiles
        self.chooseDirectories = chooseDirectories
        self.allowedContentTypes = allowedContentTypes
        self.showsHiddenFiles = showsHiddenFiles
        self.error = error
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: KumaSpacing.xs) {
            if !label.isEmpty {
                Text(label)
                    .font(KumaFont.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: KumaSpacing.sm) {
                ZStack(alignment: .leading) {
                    if path.isEmpty {
                        Text(placeholder)
                            .font(KumaFont.body)
                            .foregroundStyle(Color(nsColor: .placeholderTextColor))
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $path)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                }
                    .padding(KumaSpacing.sm)
                    .background(KumaColors.inputBackground, in: RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous)
                            .stroke(
                                isFocused ? Color.accentColor : KumaColors.inputBorder,
                                lineWidth: isFocused ? 1.5 : 0.5
                            )
                    )

                Button("Browse") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseFiles = chooseFiles
                    panel.canChooseDirectories = chooseDirectories
                    panel.showsHiddenFiles = showsHiddenFiles
                    panel.resolvesAliases = true

                    if let allowedContentTypes {
                        panel.allowedContentTypes = allowedContentTypes
                    }

                    // Smart initial directory: focus on current path or placeholder directory if exists
                    let targetPath = path.isEmpty ? placeholder : path
                    let expanded = NSString(string: targetPath).expandingTildeInPath
                    let dirPath = (expanded as NSString).deletingLastPathComponent
                    if FileManager.default.fileExists(atPath: dirPath) {
                        panel.directoryURL = URL(fileURLWithPath: dirPath)
                    }

                    if panel.runModal() == .OK {
                        if let selectedURL = panel.url {
                            path = selectedURL.path(percentEncoded: false)
                        }
                    }
                }

                .buttonStyle(.bordered)
            }

            if let error, !error.isEmpty {
                Text(error)
                    .font(KumaFont.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var path1 = "/usr/local/bin/docker"
        @State private var path2 = "/invalid/path/test"
        var body: some View {
            VStack(spacing: 16) {
                KumaFilePickerField(
                    label: "Docker Binary",
                    path: $path1,
                    placeholder: "/usr/local/bin/docker"
                )
                KumaFilePickerField(
                    label: "Custom Script Path",
                    path: $path2,
                    placeholder: "/path/to/script.sh",
                    error: "File does not exist at specified path"
                )
            }
            .padding()
            .frame(width: 500)
        }
    }
    return PreviewWrapper()
}
