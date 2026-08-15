import SwiftUI

/// Ultra-lightweight micro-observer sub-view for live service status and toggle buttons.
/// Sub-views isolate live updates so only this small footprint re-renders upon state change.
public struct ServiceStatusObserver: View {
    public let state: ServiceRuntimeState

    public init(state: ServiceRuntimeState) {
        self.state = state
    }

    public var body: some View {
        StatusPillView(
            text: state.status.title.lowercased(),
            color: state.status.color,
            showDot: true,
            isGlowing: state.status == .running,
            isLoading: state.isLoading || state.status == .starting || state.status == .stopping
        )
    }
}
