//
//  WorkspaceStoreTests.swift
//  KumaTests
//
//  Created for Kuma Native macOS App.
//

import Testing
import Foundation
@testable import Kuma

@Suite("WorkspaceStore Tests")
@MainActor
struct WorkspaceStoreTests {

    @Test("WorkspaceStore initial default state")
    func testInitialState() {
        let testDefaults = UserDefaults(suiteName: "kuma.test.\(UUID().uuidString)")!
        let store = WorkspaceStore(userDefaults: testDefaults)
        #expect(store.workspaces.count == 1)
        #expect(store.workspaces.first?.name == Workspace.defaultName)
        #expect(store.activeWorkspace?.name == Workspace.defaultName)
    }

    @Test("WorkspaceStore add, rename, select, and delete")
    func testWorkspaceOperations() {
        let testDefaults = UserDefaults(suiteName: "kuma.test.\(UUID().uuidString)")!
        let store = WorkspaceStore(userDefaults: testDefaults)

        // 1. Add
        let staging = store.addWorkspace(name: "Staging Cluster")
        #expect(store.workspaces.count == 2)
        #expect(store.selectedWorkspaceId == staging.id)
        #expect(store.activeWorkspace?.name == "Staging Cluster")

        // 2. Rename
        store.renameWorkspace(staging, newName: "Staging V2")
        #expect(store.activeWorkspace?.name == "Staging V2")

        // 3. Select back to default
        if let defaultWS = store.workspaces.first(where: { $0.id != staging.id }) {
            store.selectWorkspace(defaultWS)
            #expect(store.activeWorkspace?.name == Workspace.defaultName)
        }

        // 4. Update (Name + ImagePath)
        var stagingToUpdate = staging
        stagingToUpdate.name = "Staging V3"
        stagingToUpdate.imagePath = "/custom/path/logo.png"
        store.updateWorkspace(stagingToUpdate)
        let updatedStaging = store.workspaces.first(where: { $0.id == staging.id })
        #expect(updatedStaging?.name == "Staging V3")
        #expect(updatedStaging?.imagePath == "/custom/path/logo.png")

        // 5. Sheet presentation states
        store.showCreateSheet = true
        #expect(store.showCreateSheet == true)
        store.workspaceToEdit = stagingToUpdate
        #expect(store.workspaceToEdit?.id == staging.id)

        // 6. Delete
        store.deleteWorkspace(staging)
        #expect(store.workspaces.count == 1)
        #expect(store.activeWorkspace?.name == Workspace.defaultName)
    }
}
