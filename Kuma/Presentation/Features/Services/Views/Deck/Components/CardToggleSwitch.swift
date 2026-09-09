import SwiftUI

/// Isolated micro-view for the ServiceCardView toggle switch button.
public struct CardToggleSwitch: View {
    public let isDisabled: Bool
    public let runtime: ServiceRuntimeState
    public let onToggle: () -> Void

    public init(
        isDisabled: Bool,
        runtime: ServiceRuntimeState,
        onToggle: @escaping () -> Void
    ) {
        self.isDisabled = isDisabled
        self.runtime = runtime
        self.onToggle = onToggle
    }

    public var body: some View {
        if isDisabled {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.tertiary)
        } else {
            let isRunning = runtime.status == .running || runtime.status == .starting
            Toggle("", isOn: Binding<Bool>(
                get: { isRunning },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .labelsHidden()
            .disabled(runtime.isLoading || runtime.status == .starting || runtime.status == .stopping)
        }
    }
}
