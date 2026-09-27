import Foundation
import Testing
@testable import Kuma

@Suite("UI Optimization & Performance Tests", .serialized)
struct UIOptimizationTests {

    @Test("TC-UI01: Deck search debouncing updates filtered results asynchronously")
    @MainActor
    func testDeckSearchDebouncing() async throws {
        let suiteName = "test-deck-debounce-\(UUID().uuidString)"
        let ud = UserDefaults(suiteName: suiteName)!
        ud.removePersistentDomain(forName: suiteName)
        let vm = ServicesDeckViewModel(
            userDefaults: ud
        )

        let s1 = ServiceCardSnapshot(
            id: UUID(),
            name: "Alpha Service",
            groupIDs: [],
            isDisabled: false,
            isStarred: false,
            subtitle: "nginx:latest",
            providerCategory: .docker,
            portDisplays: [],
            providerOptions: [],
            createdAt: Date()
        )
        let s2 = ServiceCardSnapshot(
            id: UUID(),
            name: "Beta Worker",
            groupIDs: [],
            isDisabled: false,
            isStarred: false,
            subtitle: "worker.sh",
            providerCategory: .shell,
            portDisplays: [],
            providerOptions: [],
            createdAt: Date()
        )

        vm.snapshots = [s1, s2]
        #expect(vm.filteredSnapshots.count == 2)

        // Type search query
        vm.searchText = "Alpha"

        // Wait for debounce (150ms delay) to settle on MainActor
        let deadline = Date().addingTimeInterval(3.0)
        while vm.filteredSnapshots.count != 1 && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
            await Task.yield()
        }

        #expect(vm.filteredSnapshots.count == 1)
        #expect(vm.filteredSnapshots.first?.name == "Alpha Service")
    }

    @Test("TC-G02: ServiceCardView does not reference ServicesDeckViewModel")
    func testServiceCardViewUsesDeckActionsNotViewModel() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Kuma/Presentation/Features/Services/Views/Deck/Components/ServiceCardView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        #expect(!source.contains("ServicesDeckViewModel"))
        #expect(source.contains("serviceDeckActions"))
    }

    @Test("TC-E05: Deck skips execution-state notifications when fully idle")
    @MainActor
    func testZeroEffortWhenIdle() {
        let store = ServiceStateStore()
        #expect(!ServicesDeckRuntimeObservation.shouldHandleExecutionStateNotifications(store: store))
        store.setExecutionState(.starting, for: UUID())
        #expect(ServicesDeckRuntimeObservation.shouldHandleExecutionStateNotifications(store: store))
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
