import SwiftUI

/// Per-card runtime observer — keeps `ServiceStateStore` out of the grid parent `ForEach`.
public struct ServiceCardRow: View {
    public let snapshot: ServiceCardSnapshot
    public let isSelected: Bool

    @Environment(ServiceStateStore.self) private var serviceStateStore

    public init(snapshot: ServiceCardSnapshot, isSelected: Bool) {
        self.snapshot = snapshot
        self.isSelected = isSelected
    }

    public var body: some View {
        ServiceCardView(
            snapshot: snapshot,
            runtime: serviceStateStore.runtime(for: snapshot.id),
            isSelected: isSelected
        )
        .equatable()
    }
}
