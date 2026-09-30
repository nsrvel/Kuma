import Testing
import Foundation
@testable import Kuma

@Suite("SidebarViewModel Tests")
@MainActor
struct SidebarViewModelTests {

    @Test("Default sidebar shows All Services, Starred, Port Registry, Live Logs, and Groups")
    func testDefaultSidebar() {
        let store = SidebarViewModel.makeDefault()
        #expect(store.entries.count == 5) // 5 items
        #expect(store.selectedID == .stable("all-services"))

        if case .item(let node) = store.entries[0] {
            #expect(node.title == "All Services")
        }
    }

    @Test("Custom initial entries and selection")
    func testCustomInitialization() {
        let customID = UUID.stable("custom-item")
        let store = SidebarViewModel(
            entries: [
                .item(SidebarNode(id: customID, title: "Custom", icon: .system("star")))
            ],
            selectedID: customID
        )

        #expect(store.entries.count == 1)
        #expect(store.selectedID == customID)
    }

    @Test("Expansion toggle still works")
    func testExpansionToggle() {
        let store = SidebarViewModel.makeDefault()
        let id = UUID.stable("test-id")

        #expect(store.isExpanded(id) == false)
        store.toggleExpanded(id)
        #expect(store.isExpanded(id) == true)
        store.toggleExpanded(id)
        #expect(store.isExpanded(id) == false)
    }
}
