import AppKit
import SwiftUI

struct ServiceDeckCollectionView: NSViewRepresentable {
    let viewModel: ServicesDeckViewModel
    let workspaceID: UUID

    @Environment(ServiceStateStore.self) private var serviceStateStore

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let collectionView = NSCollectionView()
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = false
        collectionView.autoresizingMask = [.width]
        scrollView.documentView = collectionView
        collectionView.frame = scrollView.contentView.bounds

        context.coordinator.controller.attach(to: collectionView)

        context.coordinator.scrollView = scrollView

        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.clipViewBoundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: clipView
        )

        pushUpdate(to: scrollView, context: context)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        pushUpdate(to: nsView, context: context)
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    private func pushUpdate(to scrollView: NSScrollView, context: Context) {
        context.coordinator.viewModel = viewModel
        context.coordinator.workspaceID = workspaceID
        context.coordinator.serviceStateStore = serviceStateStore

        let contentWidth = max(scrollView.contentView.bounds.width, scrollView.bounds.width)
        context.coordinator.controller.update(
            snapshots: viewModel.filteredSnapshots,
            viewModel: viewModel,
            workspaceID: workspaceID,
            serviceStateStore: serviceStateStore,
            filterVersion: viewModel.filterVersion,
            contentWidth: contentWidth,
            previousFilterVersion: &context.coordinator.lastFilterVersion,
            previousSnapshotIDs: &context.coordinator.lastSnapshotIDs,
            previousSnapshots: &context.coordinator.lastSnapshots,
            previousSelectedID: &context.coordinator.lastSelectedID
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject {
        let controller = ServiceDeckCollectionViewController()
        weak var scrollView: NSScrollView?

        var viewModel: ServicesDeckViewModel?
        var workspaceID: UUID?
        var serviceStateStore: ServiceStateStore?

        var lastFilterVersion = -1
        var lastSnapshotIDs: [UUID] = []
        var lastSnapshots: [ServiceCardSnapshot] = []
        var lastSelectedID: UUID?

        @objc func clipViewBoundsDidChange(_ notification: Notification) {
            guard let scrollView else { return }
            controller.relayout(contentWidth: scrollView.contentView.bounds.width)
        }
    }
}
