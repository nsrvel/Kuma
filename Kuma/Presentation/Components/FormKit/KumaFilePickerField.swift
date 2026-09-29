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
    /// When true, NSOpenPanel still lists extensionless files (e.g. `~/.kube/config`).
    public var allowsOtherFileTypes: Bool
    /// Overrides initial folder for Browse; receives the current path binding value.
    public var browseDirectory: ((String) -> URL)?
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
        allowsOtherFileTypes: Bool = false,
        browseDirectory: ((String) -> URL)? = nil,
        showsHiddenFiles: Bool = true,
        error: String? = nil
    ) {
        self.label = label
        self._path = path
        self.placeholder = placeholder
        self.chooseFiles = chooseFiles
        self.chooseDirectories = chooseDirectories
        self.allowedContentTypes = allowedContentTypes
        self.allowsOtherFileTypes = allowsOtherFileTypes
        self.browseDirectory = browseDirectory
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
                    .background(KumaColors.inputFieldFill, in: RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: KumaRadius.sm, style: .continuous)
                            .stroke(
                                isFocused ? Color.accentColor : KumaColors.inputFieldStroke,
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
                    panel.allowsOtherFileTypes = allowsOtherFileTypes

                    if let browseDirectory {
                        panel.directoryURL = browseDirectory(path)
                    } else {
                        panel.directoryURL = Self.defaultBrowseDirectory(
                            path: path,
                            placeholder: placeholder
                        )
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

    private static func defaultBrowseDirectory(path: String, placeholder: String) -> URL {
        let fm = FileManager.default
        let targetPath = path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? placeholder : path
        if !targetPath.isEmpty {
            let expanded = NSString(string: targetPath).expandingTildeInPath
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue {
                return URL(fileURLWithPath: expanded, isDirectory: true)
            }
            let dirPath = (expanded as NSString).deletingLastPathComponent
            if fm.fileExists(atPath: dirPath) {
                return URL(fileURLWithPath: dirPath, isDirectory: true)
            }
        }
        return fm.homeDirectoryForCurrentUser
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
