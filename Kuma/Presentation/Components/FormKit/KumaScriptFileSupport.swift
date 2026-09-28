import AppKit
import SwiftUI
import UniformTypeIdentifiers

public enum KumaScriptFileSupport {
    public static let allowedTypes: [UTType] = {
        var types: [UTType] = []
        if let sh = UTType(filenameExtension: "sh") { types.append(sh) }
        if let bash = UTType(filenameExtension: "bash") { types.append(bash) }
        types.append(.shellScript)
        types.append(.plainText)
        return types
    }()

    public static func pickFile(into binding: Binding<String>) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = allowedTypes
        if panel.runModal() == .OK, let url = panel.url {
            binding.wrappedValue = url.path(percentEncoded: false)
        }
    }

    public static func revealInFinder(path: String) {
        let expanded = NSString(string: path).expandingTildeInPath
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: expanded)])
    }
}
