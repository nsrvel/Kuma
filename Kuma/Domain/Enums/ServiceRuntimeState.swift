import Foundation

/// Fast and lightweight runtime state container that holds frequent live updates.
/// Kept strictly isolated from static metadata so status changes only invalidate micro-observers.
public struct ServiceRuntimeState: Sendable, Equatable {
    public var status: ServiceState
    public var isLoading: Bool

    /// Shared zero-allocation default for dictionary miss lookups
    public static let idle = ServiceRuntimeState()

    public init(
        status: ServiceState = .stopped,
        isLoading: Bool = false
    ) {
        self.status = status
        self.isLoading = isLoading
    }
}
