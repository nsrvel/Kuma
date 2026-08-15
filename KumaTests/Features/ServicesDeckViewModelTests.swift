import Foundation
import Testing
@testable import Kuma

@Suite("Presentation Feature Tests: ServicesDeckViewModel")
@MainActor
struct ServicesDeckViewModelTests {

    private func createTestViewModelWithData() async -> (ServicesDeckViewModel, UUID) {
        let db = AppDatabase(inMemory: true)
        let wsRepo = WorkspaceRepository(dbWriter: db.dbWriter)
        let repo = ServiceRepository(dbWriter: db.dbWriter)
        let vm = ServicesDeckViewModel(serviceRepository: repo)

        let wid = UUID()
        let ws = Workspace(id: wid, name: "Test Space")
        try? await wsRepo.insert(ws)

        let s1 = Service(name: "PostgreSQL Database", workspaceID: wid)
        let s2 = Service(name: "Redis Cache", workspaceID: wid)
        let s3 = Service(name: "Backend Node API", workspaceID: wid)
        let s4 = Service(name: "Frontend Next.js App", workspaceID: wid)

        let p1 = Provider(serviceID: s1.id, type: .docker)
        let p2 = Provider(serviceID: s2.id, type: .docker)
        let p3 = Provider(serviceID: s3.id, type: .shell)
        let p4 = Provider(serviceID: s4.id, type: .shell)

        try? await repo.insertService(s1, defaultProvider: p1, portMappings: [ServicePortMapping(localPort: 5432, remotePort: 5432)])
        try? await repo.insertService(s2, defaultProvider: p2, portMappings: [ServicePortMapping(localPort: 6379, remotePort: 6379)])
        try? await repo.insertService(s3, defaultProvider: p3, portMappings: [ServicePortMapping(localPort: 8080, remotePort: 8080)])
        try? await repo.insertService(s4, defaultProvider: p4, portMappings: [ServicePortMapping(localPort: 3000, remotePort: 3000)])

        await vm.loadWorkspaceAsync(workspaceID: wid)
        return (vm, wid)
    }

    @Test("ServicesDeckViewModel loads initial workspace data")
    func testLoadWorkspace() async {
        let (vm, _) = await createTestViewModelWithData()

        #expect(vm.snapshots.count == 4)
        #expect(vm.filteredSnapshots.count == 4)
    }

    @Test("ServicesDeckViewModel filters services by search query")
    func testSearchFiltering() async {
        let (vm, _) = await createTestViewModelWithData()

        vm.searchText = "postgres"
        #expect(vm.filteredSnapshots.count == 1)
        #expect(vm.filteredSnapshots.first?.name == "PostgreSQL Database")

        vm.searchText = "non_existent_search_query"
        #expect(vm.filteredSnapshots.isEmpty == true)
    }

    @Test("ServicesDeckViewModel toggles operational status")
    func testStatusToggle() async {
        let (vm, _) = await createTestViewModelWithData()
        let snapshot = vm.snapshots.first!

        let initialState = vm.runtimeStates[snapshot.id]?.status ?? .stopped
        vm.toggleService(id: snapshot.id)
        let toggledState = vm.runtimeStates[snapshot.id]?.status ?? .stopped

        #expect(initialState != toggledState)
    }

    @Test("ServicesDeckViewModel handles selection and inspector trigger")
    func testSelectService() async {
        let (vm, _) = await createTestViewModelWithData()
        let snapshot = vm.snapshots.first!

        #expect(vm.selectedServiceID == nil)
        #expect(vm.isInspectorPresented == false)

        vm.selectService(snapshot.id)

        #expect(vm.selectedServiceID == snapshot.id)
        #expect(vm.isInspectorPresented == true)
    }

    @Test("ServicesDeckViewModel filters services by provider category")
    func testProviderFiltering() async {
        let (vm, _) = await createTestViewModelWithData()

        #expect(vm.filteredSnapshots.count == 4)

        // Filter Docker only
        vm.selectedProviders = [.docker]
        #expect(vm.filteredSnapshots.count == 2)
        #expect(vm.filteredSnapshots.allSatisfy { $0.providerCategory == .docker })

        // Filter Shell only
        vm.selectedProviders = [.shell]
        #expect(vm.filteredSnapshots.count == 2)
        #expect(vm.filteredSnapshots.allSatisfy { $0.providerCategory == .shell })

        // Reset
        vm.selectedProviders.removeAll()
        #expect(vm.filteredSnapshots.count == 4)
    }
}
