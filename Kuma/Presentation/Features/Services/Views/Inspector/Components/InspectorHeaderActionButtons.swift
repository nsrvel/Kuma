import SwiftUI

/// Log panel controls in the inspector header (auto-scroll, wrap, clear, download).
public struct InspectorHeaderLogControls: View {
    @Binding public var isLogAutoScrollEnabled: Bool
    @Binding public var logWrapsLines: Bool
    public var canDownload: Bool
    public var onEnableAutoScroll: () -> Void
    public var onClear: () -> Void
    public var onDownload: () -> Void

    public init(
        isLogAutoScrollEnabled: Binding<Bool>,
        logWrapsLines: Binding<Bool>,
        canDownload: Bool,
        onEnableAutoScroll: @escaping () -> Void,
        onClear: @escaping () -> Void,
        onDownload: @escaping () -> Void
    ) {
        self._isLogAutoScrollEnabled = isLogAutoScrollEnabled
        self._logWrapsLines = logWrapsLines
        self.canDownload = canDownload
        self.onEnableAutoScroll = onEnableAutoScroll
        self.onClear = onClear
        self.onDownload = onDownload
    }

    public var body: some View {
        HStack(spacing: 6) {
            Toggle(isOn: autoScrollBinding) {
                Label("Auto-scroll", systemImage: isLogAutoScrollEnabled ? "arrow.down.to.line" : "arrow.down.to.line.slash")
            }
            .toggleStyle(.button)
            .help(isLogAutoScrollEnabled ? "Pause auto-scroll" : "Enable auto-scroll")
            .accessibilityLabel(isLogAutoScrollEnabled ? "Auto-scroll on" : "Auto-scroll off")

            Toggle(isOn: $logWrapsLines) {
                Label("Wrap lines", systemImage: logWrapsLines ? "text.word.spacing" : "arrow.left.and.right")
            }
            .toggleStyle(.button)
            .help(logWrapsLines ? "Wrap long lines" : "No wrap (horizontal scroll)")

            Button(role: .destructive, action: onClear) {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.borderless)
            .help("Clear display (stream keeps running while service is up)")

            Button(action: onDownload) {
                Label("Download", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.borderless)
            .disabled(!canDownload)
            .help("Save visible logs to a text file")
        }
        .labelStyle(.iconOnly)
    }

    private var autoScrollBinding: Binding<Bool> {
        Binding(
            get: { isLogAutoScrollEnabled },
            set: { newValue in
                isLogAutoScrollEnabled = newValue
                if newValue { onEnableAutoScroll() }
            }
        )
    }
}

public struct InspectorHeaderActionButton: View {
    public let runtime: ServiceRuntimeState
    public let onToggle: () -> Void

    public init(runtime: ServiceRuntimeState, onToggle: @escaping () -> Void) {
        self.runtime = runtime
        self.onToggle = onToggle
    }

    public var body: some View {
        let showsStop = showsStopChrome(for: runtime.status)
        let isBusy = runtime.isLoading || runtime.status == .starting || runtime.status == .stopping

        Button {
            guard !isBusy else { return }
            KumaHapticManager.shared.tap()
            onToggle()
        } label: {
            HStack(spacing: 5) {
                if isBusy {
                    KumaActivityIndicator(size: 11, color: .white, lineWidth: 1.5)
                }
                Text(showsStop ? "Stop" : "Start")
                    .frame(minWidth: 34, alignment: .center)
                    .contentTransition(.interpolate)
            }
        }
        .buttonStyle(KumaPrimaryButtonStyle.inspectorToggle(isRunning: showsStop))
        .allowsHitTesting(!isBusy)
        .padding(.trailing, 8)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(isBusy ? nil : .easeInOut(duration: 0.18), value: showsStop)
    }

    private func showsStopChrome(for status: ServiceState) -> Bool {
        switch status {
        case .running, .starting, .stopping:
            return true
        case .stopped, .crashed:
            return false
        }
    }
}
