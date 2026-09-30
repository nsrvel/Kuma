import Foundation
import Testing
@testable import Kuma

@Suite("Feature 04: Sidebar - Initial State & Baseline Contracts", .serialized)
@MainActor
struct SidebarInitialStateTests {

    @Test("TC-A01: Sidebar Default Entries Structure")
    func testSidebarDefaultEntriesStructure() {
        let vm = SidebarViewModel.makeDefault()
        #expect(vm.entries.count == 4)

        let ids = vm.entries.map(\.id)
        #expect(ids.contains(UUID.stable("all-services")))
        #expect(ids.contains(UUID.stable("starred-services")))
        #expect(ids.contains(UUID.stable("live-logs")))
        #expect(ids.contains(UUID.stable("groups")))
    }

    @Test("TC-A02: Fixed Nodes Deterministic Stable UUIDs")
    func testFixedNodesDeterministicUUIDs() {
        let expectedAllServices = UUID.stable("all-services")
        let expectedStarred = UUID.stable("starred-services")
        let expectedLiveLogs = UUID.stable("live-logs")
        let expectedGroups = UUID.stable("groups")

        let vm1 = SidebarViewModel.makeDefault()
        let vm2 = SidebarViewModel.makeDefault()

        #expect(vm1.entries[0].id == expectedAllServices)
        #expect(vm1.entries[1].id == expectedStarred)
        #expect(vm1.entries[2].id == expectedLiveLogs)
        #expect(vm1.entries[3].id == expectedGroups)

        #expect(vm1.entries[0].id == vm2.entries[0].id)
        #expect(vm1.entries[3].id == vm2.entries[3].id)
    }

    @Test("TC-A03: Default Selected Node Is All Services")
    func testDefaultSelectedNodeIsAllServices() {
        let vm = SidebarViewModel.makeDefault()
        #expect(vm.selectedID == UUID.stable("all-services"))
    }

    @Test("TC-A04: Groups Header Expanded By Default")
    func testGroupsHeaderExpandedByDefault() {
        let vm = SidebarViewModel.makeDefault()
        let groupsID = UUID.stable("groups")
        #expect(vm.isExpanded(groupsID))
        #expect(vm.expandedIDs.contains(groupsID))
    }

    @Test("TC-A05: Flattened Rows Count On Fresh Boot")
    func testFlattenedRowsCountOnFreshBoot() {
        let vm = SidebarViewModel.makeDefault()
        // 3 fixed rows (all-services, starred, live-logs)
        // 1 header row (groups)
        // 1 placeholder row (no groups) because groups is expanded and empty
        #expect(vm.flattenedRows.count == 5)
        #expect(vm.flattenedRows.last?.isPlaceholder == true)
    }

    @Test("TC-A06: Initial Editing Group ID Is Nil")
    func testInitialEditingGroupIDIsNil() {
        let vm = SidebarViewModel.makeDefault()
        #expect(vm.editingGroupID == nil)
    }
}
