//
//  WorkspaceStore.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Clean @Observable store managing workspace state, selection, and operations.
//

import Foundation
import Observation
import os

@MainActor
@Observable
public final class WorkspaceStore {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "WorkspaceStore")

    public static let storageKey = "kuma.workspaces.storage"
    public static let selectedWorkspaceKey = "kuma.selectedWorkspaceId.storage"

    private let userDefaults: UserDefaults
    public private(set) var workspaces: [Workspace] = []
    public var selectedWorkspaceId: UUID? {
        didSet {
            persistState()
        }
    }
    public var showCreateSheet: Bool = false
    public var workspaceToEdit: Workspace? = nil
    public var workspaceToDelete: Workspace? = nil

    public var activeWorkspace: Workspace? {
        workspaces.first(where: { $0.id == selectedWorkspaceId }) ?? workspaces.first
    }

    public init(initialWorkspaces: [Workspace]? = nil, userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let initial = initialWorkspaces {
            self.workspaces = initial
            self.selectedWorkspaceId = initial.first?.id
        } else if let loaded = Self.loadPersistedWorkspaces(from: userDefaults), !loaded.isEmpty {
            self.workspaces = loaded
            let savedSelectedStr = userDefaults.string(forKey: Self.selectedWorkspaceKey)
            if let savedUUID = savedSelectedStr.flatMap(UUID.init), loaded.contains(where: { $0.id == savedUUID }) {
                self.selectedWorkspaceId = savedUUID
            } else {
                self.selectedWorkspaceId = loaded.first?.id
            }
            Self.logger.debug("WorkspaceStore restored \(loaded.count) workspaces from storage")
        } else {
            let defaultWS = Workspace.defaultWorkspace
            self.workspaces = [defaultWS]
            self.selectedWorkspaceId = defaultWS.id
            persistState()
            Self.logger.debug("WorkspaceStore initialized with default starter workspace")
        }
    }

    public func selectWorkspace(_ workspace: Workspace) {
        Self.logger.info("Selected workspace: \(workspace.name)")
        self.selectedWorkspaceId = workspace.id
    }

    public func addWorkspace(name: String, imagePath: String? = nil) -> Workspace {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "New Workspace" : trimmed
        let newWorkspace = Workspace(name: finalName, imagePath: imagePath, sortOrder: workspaces.count)
        self.workspaces.append(newWorkspace)
        self.selectedWorkspaceId = newWorkspace.id
        persistState()
        Self.logger.info("Added new workspace: \(finalName)")
        return newWorkspace
    }

    public func renameWorkspace(_ workspace: Workspace, newName: String) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        workspaces[index].name = newName
        workspaces[index].updatedAt = Date()
        persistState()
        Self.logger.info("Renamed workspace \(workspace.id) to \(newName)")
    }

    public func updateWorkspace(_ workspace: Workspace) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        workspaces[index] = workspace
        persistState()
        Self.logger.info("Updated workspace \(workspace.id)")
    }

    public func deleteWorkspace(id: UUID) {
        guard workspaces.count > 1 else {
            Self.logger.warning("Attempted to delete the only remaining workspace. Disallowed.")
            return
        }

        workspaces.removeAll(where: { $0.id == id })
        if selectedWorkspaceId == id {
            selectedWorkspaceId = workspaces.first?.id
        }
        persistState()
        Self.logger.info("Deleted workspace id: \(id.uuidString)")
    }

    public func deleteWorkspace(_ workspace: Workspace) {
        deleteWorkspace(id: workspace.id)
    }

    /// Replaces all workspaces with restored backup data and persists state.
    public func restoreWorkspaces(_ restored: [Workspace]) {
        guard !restored.isEmpty else { return }
        self.workspaces = restored
        self.selectedWorkspaceId = restored.first?.id
        persistState()
        Self.logger.info("Restored \(restored.count) workspaces from backup")
    }

    // MARK: - Persistence Helpers

    private func persistState() {
        do {
            let data = try JSONEncoder().encode(workspaces)
            userDefaults.set(data, forKey: Self.storageKey)
            if let selectedWorkspaceId {
                userDefaults.set(selectedWorkspaceId.uuidString, forKey: Self.selectedWorkspaceKey)
            } else {
                userDefaults.removeObject(forKey: Self.selectedWorkspaceKey)
            }
        } catch {
            Self.logger.error("Failed to persist workspaces: \(error.localizedDescription)")
        }
    }

    private static func loadPersistedWorkspaces(from defaults: UserDefaults = .standard) -> [Workspace]? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        do {
            return try JSONDecoder().decode([Workspace].self, from: data)
        } catch {
            logger.error("Failed to decode persisted workspaces: \(error.localizedDescription)")
            return nil
        }
    }
}
