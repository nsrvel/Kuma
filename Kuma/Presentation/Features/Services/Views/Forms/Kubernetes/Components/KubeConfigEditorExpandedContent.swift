import SwiftUI

struct KubeConfigEditorExpandedContent: View {
    @Binding var sourceMode: KumaDualSourceMode
    @Binding var draftPath: String
    @Binding var draftYAML: String

    var body: some View {
        KumaDualSourceSegment(mode: $sourceMode, pasteLabel: "Paste Config")

        if sourceMode == .chooseFile {
            KumaFilePickerField(
                label: "",
                path: $draftPath,
                placeholder: KubeConfigFilePickerSupport.defaultConfigPlaceholder,
                chooseFiles: true,
                chooseDirectories: false,
                allowedContentTypes: KubeConfigFilePickerSupport.allowedContentTypes,
                allowsOtherFileTypes: true,
                browseDirectory: KubeConfigFilePickerSupport.browseDirectoryURL
            )
        } else {
            KumaCodeEditor(
                code: $draftYAML,
                placeholder: "Paste kubeconfig YAML…",
                minHeight: 120,
                maxHeight: 160
            )
        }
    }
}
