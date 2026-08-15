import Foundation
import Observation
import os

@MainActor
@Observable
public final class WorkspaceStore {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "WorkspaceStore")
    public static let selectedWorkspaceKey = "kuma.selectedWorkspaceId.storage"

    private let userDefaults: UserDefaults
    private let repository: any WorkspaceRepositoryProtocol

    public private(set) var workspaces: [Workspace] = []
    public var selectedWorkspaceId: UUID? {
        didSet {
            if let selectedWorkspaceId {
                userDefaults.set(selectedWorkspaceId.uuidString, forKey: Self.selectedWorkspaceKey)
            }
        }
    }
    public var showCreateSheet: Bool = false
    public var workspaceToEdit: Workspace? = nil
    public var workspaceToDelete: Workspace? = nil

    public var activeWorkspace: Workspace? {
        workspaces.first(where: { $0.id == selectedWorkspaceId }) ?? workspaces.first
    }

    public init(
        initialWorkspaces: [Workspace]? = nil,
        repository: any WorkspaceRepositoryProtocol = WorkspaceRepository(),
        userDefaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.userDefaults = userDefaults

        if let initial = initialWorkspaces {
            self.workspaces = initial
            self.selectedWorkspaceId = initial.first?.id
        } else {
            loadFromDatabase()
        }
    }

    public func loadFromDatabase() {
        Task {
            do {
                let fetched = try await repository.fetchAll()
                if !fetched.isEmpty {
                    self.workspaces = fetched
                    let savedSelectedStr = userDefaults.string(forKey: Self.selectedWorkspaceKey)
                    if let savedUUID = savedSelectedStr.flatMap(UUID.init), fetched.contains(where: { $0.id == savedUUID }) {
                        self.selectedWorkspaceId = savedUUID
                    } else {
                        self.selectedWorkspaceId = fetched.first?.id
                    }
                } else {
                    let defaultWS = Workspace.defaultWorkspace
                    try? await repository.insert(defaultWS)
                    self.workspaces = [defaultWS]
                    self.selectedWorkspaceId = defaultWS.id
                }
            } catch {
                Self.logger.error("Failed to load workspaces from DB: \(error)")
            }
        }
    }

    public func selectWorkspace(_ workspace: Workspace) {
        Self.logger.info("Selected workspace: \(workspace.name)")
        self.selectedWorkspaceId = workspace.id
    }

    public func addWorkspace(name: String, imagePath: String? = nil) -> Workspace {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "New Workspace" : trimmed
        let newWorkspaceID = UUID()

        // If a file URL was provided, save a managed copy into internal storage
        var finalImageFileName: String? = nil
        if let imagePath, let url = URL(string: imagePath), url.isFileURL {
            finalImageFileName = WorkspaceImageStore.shared.saveWorkspaceImage(from: url, workspaceID: newWorkspaceID)
        } else {
            finalImageFileName = imagePath
        }

        let newWorkspace = Workspace(id: newWorkspaceID, name: finalName, imagePath: finalImageFileName, sortOrder: workspaces.count)
        self.workspaces.append(newWorkspace)
        self.selectedWorkspaceId = newWorkspace.id

        Task {
            try? await repository.insert(newWorkspace)
        }
        Self.logger.info("Added new workspace: \(finalName)")
        return newWorkspace
    }

    public func renameWorkspace(_ workspace: Workspace, newName: String) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        workspaces[index].name = newName
        workspaces[index].updatedAt = Date()
        let updated = workspaces[index]

        Task {
            try? await repository.update(updated)
        }
        Self.logger.info("Renamed workspace \(workspace.id) to \(newName)")
    }

    public func updateWorkspace(_ workspace: Workspace) {
        guard let index = workspaces.firstIndex(where: { $0.id == workspace.id }) else { return }
        workspaces[index] = workspace
        workspaces[index].updatedAt = Date()
        let updated = workspaces[index]

        Task {
            try? await repository.update(updated)
        }
        Self.logger.info("Updated workspace: \(workspace.name)")
    }

    public func deleteWorkspace(_ workspace: Workspace) {
        if let imagePath = workspace.imagePath {
            WorkspaceImageStore.shared.deleteImage(for: imagePath)
        }

        workspaces.removeAll { $0.id == workspace.id }

        if selectedWorkspaceId == workspace.id {
            selectedWorkspaceId = workspaces.first?.id
        }

        Task {
            try? await repository.delete(id: workspace.id)
        }
        Self.logger.info("Deleted workspace: \(workspace.name)")
    }

    public func moveWorkspace(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex < workspaces.count && destinationIndex < workspaces.count else { return }
        workspaces.swapAt(sourceIndex, destinationIndex)

        for (index, _) in workspaces.enumerated() {
            workspaces[index].sortOrder = index
            workspaces[index].updatedAt = Date()
            let updated = workspaces[index]
            Task {
                try? await repository.update(updated)
            }
        }
    }
}
