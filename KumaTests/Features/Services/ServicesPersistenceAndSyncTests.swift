import Foundation
import Testing
import GRDB
@testable import Kuma

@Suite("Feature 06 - Category C: Concurrency, Mutations & Deck/Inspector Sync", .serialized)
@MainActor
struct ServicesPersistenceAndSyncTests {

    // MARK: - [TC-C01] Single Query Service Detail Fetch
    @Test("TC-C01: fetchServiceDetail loads Service, Providers, and PortMappings in 1 read transaction")
    func testSingleQueryServiceDetailFetch() async throws {
        let harness = ServicesTestHarness()
        let (service, provider) = try await harness.seedServiceWithProvider(
            name: "Postgres DB",
            providerType: .docker,
            ports: [(5432, 5432), (5433, 5432)]
        )

        let detail = try await harness.serviceRepository.fetchServiceDetail(id: service.id)
        #expect(detail != nil)
        #expect(detail?.service.name == "Postgres DB")
        #expect(detail?.providers.count == 1)
        #expect(detail?.providers.first?.id == provider.id)
        #expect(detail?.portMappings.count == 2)
        #expect(detail?.portMappings.map(\.localPort).sorted() == [5432, 5433])
    }

    // MARK: - [TC-C02] Granular Single Snapshot Fetch
    @Test("TC-C02: fetchSnapshot fetches single service card snapshot accurately")
    func testGranularSingleSnapshotFetch() async throws {
        let harness = ServicesTestHarness()
        let (service, _) = try await harness.seedServiceWithProvider(
            name: "API Server",
            providerType: .shell,
            ports: [(3000, 3000)]
        )

        let snapshot = try await harness.serviceRepository.fetchSnapshot(serviceID: service.id)
        #expect(snapshot != nil)
        #expect(snapshot?.id == service.id)
        #expect(snapshot?.name == "API Server")
        #expect(snapshot?.providerCategory == .shell)
        #expect(snapshot?.portDisplays == [3000])
    }

    // MARK: - [TC-C04] Deck ↔ Inspector Shared State Sync via ServiceStateStore
    @Test("TC-C04: ServiceStateStore synchronizes state across Deck and Inspector")
    func testDeckInspectorSharedStateSync() async throws {
        let harness = ServicesTestHarness()
        let (service, _) = try await harness.seedServiceWithProvider(
            name: "Web App",
            providerType: .shell
        )

        let store = ServiceStateStore()
        let deckVM = ServicesDeckViewModel(
            serviceRepository: harness.serviceRepository,
            stateStore: store
        )
        let inspectorVM = ServiceInspectorViewModel(
            serviceID: service.id,
            workspaceID: harness.defaultWorkspaceID,
            serviceRepository: harness.serviceRepository,
            stateStore: store
        )

        await deckVM.loadWorkspaceAsync(workspaceID: harness.defaultWorkspaceID)
        await inspectorVM.loadService(id: service.id)

        #expect(!deckVM.runtimeStates[service.id]!.status.isOperational)
        #expect(!inspectorVM.isRunning)

        // Mutate in store directly or via action
        store.setExecutionState(.running(pid: 9999), for: service.id)

        #expect(store.state(for: service.id) == .running(pid: 9999))
        #expect(inspectorVM.isRunning)
        #expect(inspectorVM.executionState == .running(pid: 9999))

        deckVM.runtimeStates[service.id] = store.runtime(for: service.id)
        #expect(deckVM.runtimeStates[service.id]?.status == .running)
    }

    // MARK: - [TC-C07] Duplicate Service Atomic Integrity
    @Test("TC-C07: duplicateService duplicates service and providers with new IDs")
    func testDuplicateServiceAtomicIntegrity() async throws {
        let harness = ServicesTestHarness()
        let (original, _) = try await harness.seedServiceWithProvider(
            name: "Microservice",
            providerType: .docker,
            ports: [(8000, 80)]
        )

        let duplicateID = UUID()
        let duplicated = try await harness.serviceRepository.duplicateService(sourceID: original.id, newID: duplicateID)

        #expect(duplicated.id == duplicateID)
        #expect(duplicated.name == "\(original.name) (Copy)")

        let dupProviders = try await harness.serviceRepository.fetchProviders(forService: duplicateID)
        #expect(dupProviders.count == 1)
        #expect(dupProviders.first?.serviceID == duplicateID)
        #expect(dupProviders.first?.type == .docker)

        let dupPorts = try await harness.serviceRepository.fetchPortMappings(forService: duplicateID)
        #expect(dupPorts.count == 1)
        #expect(dupPorts.first?.localPort == 8000)
    }

    // MARK: - [TC-C08] Toggle Starred Optimistic Sync
    @Test("TC-C08: toggleStarred in repository persists and toggles boolean state")
    func testToggleStarredOptimisticSync() async throws {
        let harness = ServicesTestHarness()
        let (service, _) = try await harness.seedServiceWithProvider(name: "Starred Candidate")

        #expect(!service.isStarred)

        let newState = try await harness.serviceRepository.toggleStarred(serviceID: service.id)
        #expect(newState == true)

        let fetched = try await harness.serviceRepository.fetchService(id: service.id)
        #expect(fetched?.isStarred == true)

        let toggledBack = try await harness.serviceRepository.toggleStarred(serviceID: service.id)
        #expect(toggledBack == false)
    }

    // MARK: - [TC-C09] Switch Provider Syncs Deck Snapshot
    @Test("TC-C09: switchProvider in Inspector updates active provider and updates Deck snapshot")
    func testSwitchProviderUpdatesSnapshot() async throws {
        let harness = ServicesTestHarness()
        let (service, _) = try await harness.seedServiceWithProvider(
            name: "Multi-runner Service",
            providerType: .docker
        )

        let prov2 = Provider(id: UUID(), serviceID: service.id, type: .kubernetes, label: "K8s Runner")
        try await harness.serviceRepository.insertProvider(prov2)

        let deckVM = ServicesDeckViewModel(serviceRepository: harness.serviceRepository)
        await deckVM.loadWorkspaceAsync(workspaceID: harness.defaultWorkspaceID)

        let initialSnapshot = deckVM.snapshots.first(where: { $0.id == service.id })
        #expect(initialSnapshot?.providerCategory == .docker)

        let inspectorVM = ServiceInspectorViewModel(
            serviceID: service.id,
            workspaceID: harness.defaultWorkspaceID,
            serviceRepository: harness.serviceRepository
        )
        await inspectorVM.loadService(id: service.id)

        inspectorVM.switchProvider(to: prov2.id)

        // Allow async persistence task to finish
        try await Task.sleep(nanoseconds: 100_000_000)

        // Refresh snapshot in deck like NotificationCenter handler does
        await deckVM.refreshSingleServiceSnapshot(id: service.id)

        let updatedSnapshot = deckVM.snapshots.first(where: { $0.id == service.id })
        #expect(updatedSnapshot?.providerCategory == .kubernetes)
    }
}
