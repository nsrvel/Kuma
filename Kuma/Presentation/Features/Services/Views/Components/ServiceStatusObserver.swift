import SwiftUI

/// Ultra-lightweight micro-observer sub-view for live service status and toggle buttons.
/// Sub-views isolate live updates so only this small footprint re-renders upon state change.
public struct ServiceStatusObserver: View {
    public let state: ServiceRuntimeState
    public var isDisabled: Bool

    public init(state: ServiceRuntimeState, isDisabled: Bool = false) {
        self.state = state
        self.isDisabled = isDisabled
    }

    public var body: some View {
        if isDisabled {
            StatusPillView(
                text: "disabled",
                color: Color.secondary.opacity(0.8),
                showDot: true,
                isGlowing: false,
                isLoading: false
            )
        } else {
            StatusPillView(
                text: state.status.title.lowercased(),
                color: state.status.color,
                showDot: true,
                isGlowing: false,
                isLoading: state.isLoading || state.status == .starting || state.status == .stopping
            )
        }
    }
}
