import SwiftUI

struct InitialScriptSettingsExpandedContent: View {
    @Binding var sourceMode: KumaDualSourceMode
    @Binding var draftPath: String
    @Binding var draftScript: String

    var body: some View {
        KumaDualSourceSegment(mode: $sourceMode, pasteLabel: "Paste Script")

        if sourceMode == .chooseFile {
            KumaFilePickerField(
                label: "",
                path: $draftPath,
                placeholder: "~/path/to/script.sh",
                chooseFiles: true,
                chooseDirectories: false,
                allowedContentTypes: KumaScriptFileSupport.allowedTypes
            )
        } else {
            KumaCodeEditor(
                code: $draftScript,
                placeholder: "#!/bin/sh\necho 'Preparing database migrations...'",
                minHeight: 140
            )
        }
    }
}

#Preview {
    struct Wrapper: View {
        @State private var mode = KumaDualSourceMode.chooseFile
        @State private var path = ""
        @State private var script = ""
        var body: some View {
            InitialScriptSettingsExpandedContent(
                sourceMode: $mode,
                draftPath: $path,
                draftScript: $script
            )
            .padding()
            .frame(width: 420)
        }
    }
    return Wrapper()
}
