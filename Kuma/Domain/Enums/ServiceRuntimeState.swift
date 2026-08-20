import Foundation

/// Fast and lightweight runtime state container that holds frequent live updates.
/// Kept strictly isolated from static metadata so status changes only invalidate micro-observers.
public struct ServiceRuntimeState: Sendable, Equatable {
    public var status: ServiceState
    public var isLoading: Bool

    public init(
        status: ServiceState = .stopped,
        isLoading: Bool = false
    ) {
        self.status = status
        self.isLoading = isLoading
    }
}
