import Foundation
import GRDB

public protocol WorkspaceRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Workspace]
    func insert(_ workspace: Workspace) async throws
    func update(_ workspace: Workspace) async throws
    func delete(id: UUID) async throws
}

public final class WorkspaceRepository: WorkspaceRepositoryProtocol {
    private let dbWriter: any DatabaseWriter

    public nonisolated init(dbWriter: (any DatabaseWriter)? = nil) {
        self.dbWriter = dbWriter ?? AppDatabase.shared.dbWriter
    }

    public func fetchAll() async throws -> [Workspace] {
        try await dbWriter.read { db in
            try Workspace
                .order(Column("sortOrder").asc, Column("createdAt").asc)
                .fetchAll(db)
        }
    }

    public func insert(_ workspace: Workspace) async throws {
        try await dbWriter.write { db in
            try workspace.insert(db)
        }
    }

    public func update(_ workspace: Workspace) async throws {
        try await dbWriter.write { db in
            try workspace.update(db)
        }
    }

    public func delete(id: UUID) async throws {
        try await dbWriter.write { db in
            _ = try Workspace.deleteOne(db, key: id.uuidString)
        }
    }
}
