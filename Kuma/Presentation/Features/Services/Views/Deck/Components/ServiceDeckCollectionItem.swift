import AppKit
import SwiftUI

private struct ServiceDeckHostedCard: View {
    let snapshot: ServiceCardSnapshot
    let viewModel: ServicesDeckViewModel
    let workspaceID: UUID

    @Environment(ServiceStateStore.self) private var serviceStateStore

    var body: some View {
        ServiceCardView(
            snapshot: snapshot,
            runtime: serviceStateStore.runtime(for: snapshot.id),
            isSelected: viewModel.selectedServiceID == snapshot.id,
            viewModel: viewModel,
            workspaceID: workspaceID
        )
        .equatable()
    }
}

/// AppKit-dequeued items must not be `@MainActor`-isolated or NSCollectionView cannot instantiate them.
final class ServiceDeckCollectionItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("ServiceDeckCollectionItem")

    private var hostingView: NSHostingView<AnyView>?

    override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @MainActor
    func configure(
        snapshot: ServiceCardSnapshot,
        viewModel: ServicesDeckViewModel,
        workspaceID: UUID,
        serviceStateStore: ServiceStateStore
    ) {
        let root = AnyView(
            ServiceDeckHostedCard(
                snapshot: snapshot,
                viewModel: viewModel,
                workspaceID: workspaceID
            )
            .environment(serviceStateStore)
        )

        if let hostingView {
            hostingView.rootView = root
        } else {
            let host = NSHostingView(rootView: root)
            host.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(host)
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                host.topAnchor.constraint(equalTo: view.topAnchor),
                host.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            hostingView = host
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostingView?.rootView = AnyView(Color.clear.frame(height: 1))
    }
}
