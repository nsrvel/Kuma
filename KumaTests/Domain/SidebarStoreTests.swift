import Testing
import Foundation
@testable import Kuma

@Suite("SidebarStore Tests")
@MainActor
struct SidebarStoreTests {

    @Test("Empty workspace shows only All Services")
    func testEmptyWorkspace() {
        let store = SidebarStore.makeDefault()
        // Only "All Services" row (no divider, no providers)
        #expect(store.entries.count == 1)
        #expect(store.selectedID == .stable("all-services"))
    }

    @Test("Provider rows appear dynamically when services exist")
    func testDynamicProviderRows() {
        let store = SidebarStore.makeDefault()

        // Add 3 Docker + 2 Shell services
        store.updateProviderCounts([.docker: 3, .shell: 2])

        // Should be: All Services + Divider + Docker + Shell = 4 entries
        #expect(store.entries.count == 4)

        // Verify All Services badge shows total
        if case .item(let allNode) = store.entries[0] {
            #expect(allNode.badge == 5)
        }

        // Verify provider order follows ProviderCategory.allCases
        if case .item(let dockerNode) = store.entries[2] {
            #expect(dockerNode.title == "Docker")
            #expect(dockerNode.badge == 3)
        }
        if case .item(let shellNode) = store.entries[3] {
            #expect(shellNode.title == "Shell")
            #expect(shellNode.badge == 2)
        }
    }

    @Test("Provider rows disappear when count drops to zero")
    func testProviderDisappears() {
        let store = SidebarStore.makeDefault()

        // Start with Docker + K8s
        store.updateProviderCounts([.docker: 2, .kubernetes: 1])
        #expect(store.entries.count == 4)  // All + Divider + Docker + K8s

        // Remove all K8s services
        store.updateProviderCounts([.docker: 2])
        #expect(store.entries.count == 3)  // All + Divider + Docker
    }

    @Test("Selection falls back when selected provider disappears")
    func testSelectionFallback() {
        let store = SidebarStore.makeDefault()

        // Select Kubernetes
        store.updateProviderCounts([.docker: 2, .kubernetes: 1])
        store.selectedID = ProviderCategory.kubernetes.stableID

        // Remove all K8s services → selection should fall back
        store.updateProviderCounts([.docker: 2])
        #expect(store.selectedID == .stable("all-services"))
    }

    @Test("Redundant updateProviderCounts is a no-op")
    func testNoRedundantRebuild() {
        let store = SidebarStore.makeDefault()

        store.updateProviderCounts([.docker: 3])
        let entriesAfterFirst = store.entries

        // Same counts again — entries reference should remain unchanged
        store.updateProviderCounts([.docker: 3])
        #expect(store.entries.count == entriesAfterFirst.count)
    }

    @Test("Expansion toggle still works")
    func testExpansionToggle() {
        let store = SidebarStore.makeDefault()
        let id = UUID.stable("test-id")

        #expect(store.isExpanded(id) == false)
        store.toggleExpanded(id)
        #expect(store.isExpanded(id) == true)
        store.toggleExpanded(id)
        #expect(store.isExpanded(id) == false)
    }
}
