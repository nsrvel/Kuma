import AppKit

enum ServiceDeckSection: Hashable {
    case main
}

@MainActor
final class ServiceDeckCollectionViewController: NSObject {
    static let minColumnWidth: CGFloat = 280
    static let spacing: CGFloat = 16
    static let contentInset: CGFloat = 16
    static let estimatedRowHeight: CGFloat = 118

    private weak var collectionView: NSCollectionView?
    private var dataSource: NSCollectionViewDiffableDataSource<ServiceDeckSection, UUID>?

    private var snapshotByID: [UUID: ServiceCardSnapshot] = [:]
    private var orderedIDs: [UUID] = []

    private var viewModel: ServicesDeckViewModel?
    private var workspaceID: UUID?
    private var serviceStateStore: ServiceStateStore?

    private var lastLayoutColumnCount: Int = 1
    private var lastContentWidth: CGFloat = 0

    func attach(to collectionView: NSCollectionView) {
        self.collectionView = collectionView
        collectionView.register(
            ServiceDeckCollectionItem.self,
            forItemWithIdentifier: ServiceDeckCollectionItem.reuseIdentifier
        )
        collectionView.collectionViewLayout = Self.makeLayout(columns: 1)
        let source = makeDataSource(collectionView: collectionView)
        collectionView.dataSource = source
    }

    func relayout(contentWidth: CGFloat) {
        updateLayoutIfNeeded(contentWidth: contentWidth)
    }

    func update(
        snapshots: [ServiceCardSnapshot],
        viewModel: ServicesDeckViewModel,
        workspaceID: UUID,
        serviceStateStore: ServiceStateStore,
        filterVersion: Int,
        contentWidth: CGFloat,
        previousFilterVersion: inout Int,
        previousSnapshotIDs: inout [UUID],
        previousSnapshots: inout [ServiceCardSnapshot],
        previousSelectedID: inout UUID?
    ) {
        self.viewModel = viewModel
        self.workspaceID = workspaceID
        self.serviceStateStore = serviceStateStore

        snapshotByID = Dictionary(snapshots.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        orderedIDs = snapshots.map(\.id)

        updateLayoutIfNeeded(contentWidth: contentWidth)

        let ids = orderedIDs
        let listChanged = filterVersion != previousFilterVersion || ids != previousSnapshotIDs
        let selectionChanged = viewModel.selectedServiceID != previousSelectedID
        let snapshotContentChanged = snapshots != previousSnapshots

        if listChanged {
            let animating = previousFilterVersion >= 0 && filterVersion != previousFilterVersion
            applySnapshot(animating: animating)
            previousFilterVersion = filterVersion
            previousSnapshotIDs = ids
            previousSnapshots = snapshots
        } else if selectionChanged || snapshotContentChanged {
            reconfigureVisibleItems()
            previousSnapshots = snapshots
        }

        previousSelectedID = viewModel.selectedServiceID
    }

    private func makeDataSource(collectionView: NSCollectionView) -> NSCollectionViewDiffableDataSource<ServiceDeckSection, UUID> {
        // ponytail: fall back to direct init if dequeue fails on some macOS builds.
        let source = NSCollectionViewDiffableDataSource<ServiceDeckSection, UUID>(collectionView: collectionView) { [weak self] collectionView, indexPath, serviceID in
            guard let self,
                  let snapshot = self.snapshotByID[serviceID],
                  let viewModel = self.viewModel,
                  let workspaceID = self.workspaceID,
                  let store = self.serviceStateStore
            else {
                return NSCollectionViewItem()
            }

            let item: ServiceDeckCollectionItem
            if let dequeued = collectionView.makeItem(
                withIdentifier: ServiceDeckCollectionItem.reuseIdentifier,
                for: indexPath
            ) as? ServiceDeckCollectionItem {
                item = dequeued
            } else {
                item = ServiceDeckCollectionItem(nibName: nil, bundle: nil)
            }
            item.configure(
                snapshot: snapshot,
                viewModel: viewModel,
                workspaceID: workspaceID,
                serviceStateStore: store
            )
            return item
        }
        dataSource = source
        return source
    }

    private func applySnapshot(animating: Bool) {
        guard let dataSource else { return }
        var snapshot = NSDiffableDataSourceSnapshot<ServiceDeckSection, UUID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(orderedIDs, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: animating)
    }

    private func reconfigureVisibleItems() {
        guard let collectionView else { return }
        let paths = collectionView.indexPathsForVisibleItems()
        guard !paths.isEmpty else { return }
        for indexPath in paths {
            guard let item = collectionView.item(at: indexPath) as? ServiceDeckCollectionItem,
                  let serviceID = dataSource?.itemIdentifier(for: indexPath),
                  let snapshot = snapshotByID[serviceID],
                  let viewModel,
                  let workspaceID,
                  let store = serviceStateStore
            else { continue }
            item.configure(
                snapshot: snapshot,
                viewModel: viewModel,
                workspaceID: workspaceID,
                serviceStateStore: store
            )
        }
    }

    private func updateLayoutIfNeeded(contentWidth: CGFloat) {
        guard let collectionView else { return }
        let width = max(0, contentWidth - Self.contentInset * 2)
        guard width > 0 else { return }

        let columns = ServiceDeckGridLayout.columnCount(
            forWidth: width,
            minColumnWidth: Self.minColumnWidth,
            spacing: Self.spacing
        )

        if abs(lastContentWidth - contentWidth) < 0.5, columns == lastLayoutColumnCount {
            return
        }

        lastContentWidth = contentWidth
        lastLayoutColumnCount = columns
        collectionView.collectionViewLayout = Self.makeLayout(columns: columns)
    }

    private static func makeLayout(columns: Int) -> NSCollectionViewCompositionalLayout {
        let columns = max(1, columns)
        let fraction = 1.0 / CGFloat(columns)
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(fraction),
            heightDimension: .estimated(estimatedRowHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(estimatedRowHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
        group.interItemSpacing = .fixed(spacing)
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = spacing
        section.contentInsets = NSDirectionalEdgeInsets(
            top: contentInset,
            leading: contentInset,
            bottom: contentInset,
            trailing: contentInset
        )
        return NSCollectionViewCompositionalLayout(section: section)
    }
}
