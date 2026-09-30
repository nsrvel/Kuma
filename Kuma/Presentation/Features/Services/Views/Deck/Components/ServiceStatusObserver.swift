import SwiftUI

/// Micro-view for live service status on deck cards and table rows.
public struct ServiceStatusObserver: View {
    public let state: ServiceRuntimeState
    public var isDisabled: Bool

    public init(state: ServiceRuntimeState, isDisabled: Bool = false) {
        self.state = state
        self.isDisabled = isDisabled
    }

    public var body: some View {
        StatusPillView(runtime: state, isDisabled: isDisabled)
    }
}
