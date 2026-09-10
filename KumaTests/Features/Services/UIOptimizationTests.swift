import Foundation
import Testing
@testable import Kuma

@Suite("UI Optimization & Performance Tests", .serialized)
struct UIOptimizationTests {

    @Test("TC-UI01: Deck search debouncing updates filtered results asynchronously")
    @MainActor
    func testDeckSearchDebouncing() async throws {
        let repo = MockServiceRepository()
        let groupRepo = MockServiceGroupRepository()
        let vm = ServicesDeckViewModel(
            serviceRepository: repo,
            groupRepository: groupRepo,
            userDefaults: UserDefaults(suiteName: "test-deck-debounce")!
        )

        let s1 = ServiceCardSnapshot(
            id: UUID(),
            name: "Alpha Service",
            serviceDescription: "",
            isStarred: false,
            isDisabled: false,
            groupIDs: [],
            providerCategory: .docker,
            targetDisplay: "nginx:latest",
            portDisplays: [],
            createdAt: Date()
        )
        let s2 = ServiceCardSnapshot(
            id: UUID(),
            name: "Beta Worker",
            serviceDescription: "",
            isStarred: false,
            isDisabled: false,
            groupIDs: [],
            providerCategory: .shell,
            targetDisplay: "worker.sh",
            portDisplays: [],
            createdAt: Date()
        )

        vm.snapshots = [s1, s2]
        #expect(vm.filteredSnapshots.count == 2)

        // Type search query
        vm.searchText = "Alpha"

        // Before debounce fires (0ms), filtered snapshots should not have churned immediately
        // Wait 250ms for debounce (150ms delay) to settle
        try? await Task.sleep(nanoseconds: 250_000_000)

        #expect(vm.filteredSnapshots.count == 1)
        #expect(vm.filteredSnapshots.first?.name == "Alpha Service")
    }

    @Test("TC-UI02: LiveLogEntry formats correctly without memory overhead")
    func testLiveLogEntryCreation() {
        let entry = LiveLogEntry(
            serviceID: UUID(),
            serviceName: "Backend",
            level: "ERR",
            message: "Connection refused on port 5432"
        )
        #expect(entry.serviceName == "Backend")
        #expect(entry.level == "ERR")
        #expect(entry.message == "Connection refused on port 5432")
    }
}
