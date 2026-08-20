import SwiftUI

// MARK: - InitialScriptSettingsView

/// Pre-startup shell script editor for Docker and Podman containers.
public struct InitialScriptSettingsView: View {
    @Binding public var initialScript: String

    public init(initialScript: Binding<String>) {
        self._initialScript = initialScript
    }

    public var body: some View {
        KumaCollapsibleCodeField(
            label: "Startup Script (sh / bash)",
            value: $initialScript,
            placeholder: "#!/bin/sh\necho 'Preparing database migrations...'\n# Add any pre-startup commands here",
            height: 110,
            configureActionTitle: "Configure Startup Script",
            revealActionTitle: "Reveal Startup Script",
            iconName: "terminal.fill"
        )
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var script = "echo 'Running migrations...'\nnpx prisma migrate deploy"

        var body: some View {
            KumaFormSection(
                icon: "terminal.fill",
                title: "Initial Script"
            ) {
                InitialScriptSettingsView(initialScript: $script)
            }
            .padding()
            .frame(width: 500)
            .background(KumaColors.canvasBackground)
        }
    }
    return PreviewWrapper()
}
