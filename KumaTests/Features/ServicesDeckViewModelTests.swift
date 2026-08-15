//
//  ServicesDeckViewModelTests.swift
//  KumaTests
//
//  Created for Kuma Native macOS App.
//

import Foundation
import Testing
@testable import Kuma

@Suite("Presentation Feature Tests: ServicesDeckViewModel")
@MainActor
struct ServicesDeckViewModelTests {

    @Test("ServicesDeckViewModel loads initial workspace sample data")
    func testLoadWorkspace() {
        let vm = ServicesDeckViewModel()
        let wid = UUID()

        #expect(vm.services.isEmpty == true)
        vm.loadWorkspace(workspaceID: wid)

        #expect(vm.services.count == 4)
        #expect(vm.filteredServices.count == 4)
    }

    @Test("ServicesDeckViewModel filters services by search query")
    func testSearchFiltering() {
        let vm = ServicesDeckViewModel()
        vm.loadWorkspace(workspaceID: UUID())

        vm.searchText = "postgres"
        #expect(vm.filteredServices.count == 1)
        #expect(vm.filteredServices.first?.name == "PostgreSQL Database")

        vm.searchText = "non_existent_search_query"
        #expect(vm.filteredServices.isEmpty == true)
    }

    @Test("ServicesDeckViewModel toggles operational status")
    func testStatusToggle() {
        let vm = ServicesDeckViewModel()
        vm.loadWorkspace(workspaceID: UUID())
        let service = vm.services.first!

        let initialState = vm.serviceStates[service.id] ?? .stopped
        vm.toggleService(service)
        let toggledState = vm.serviceStates[service.id] ?? .stopped

        #expect(initialState != toggledState)
    }

    @Test("ServicesDeckViewModel handles selection and inspector trigger")
    func testSelectService() {
        let vm = ServicesDeckViewModel()
        vm.loadWorkspace(workspaceID: UUID())
        let service = vm.services.first!

        #expect(vm.selectedServiceID == nil)
        #expect(vm.isInspectorPresented == false)

        vm.selectService(service.id)

        #expect(vm.selectedServiceID == service.id)
        #expect(vm.isInspectorPresented == true)
    }

    @Test("ServicesDeckViewModel filters services by provider category")
    func testProviderFiltering() {
        let vm = ServicesDeckViewModel()
        vm.loadWorkspace(workspaceID: UUID())

        #expect(vm.filteredServices.count == 4)

        // Filter Docker only
        vm.selectedProviders = [.docker]
        #expect(vm.filteredServices.count == 2)
        #expect(vm.filteredServices.allSatisfy { vm.serviceProviders[$0.id] == .docker })

        // Filter Shell only
        vm.selectedProviders = [.shell]
        #expect(vm.filteredServices.count == 2)
        #expect(vm.filteredServices.allSatisfy { vm.serviceProviders[$0.id] == .shell })

        // Reset
        vm.selectedProviders.removeAll()
        #expect(vm.filteredServices.count == 4)
    }
}
