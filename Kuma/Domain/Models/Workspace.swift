//
//  Workspace.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Pure zero-dependency domain model representing an isolated Workspace environment.
//

import Foundation

public struct Workspace: Identifiable, Codable, Sendable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var imagePath: String?
    public var sortOrder: Int
    public let createdAt: Date
    public var updatedAt: Date

    public nonisolated init(
        id: UUID = UUID(),
        name: String,
        imagePath: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.imagePath = imagePath
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension Workspace {
    /// Resolves the user's macOS account name into a personalized workspace title (e.g. "Putra's Space").
    public nonisolated static var defaultName: String {
        let fullName = NSFullUserName()
        let baseName = fullName.isEmpty ? NSUserName() : fullName
        let firstName = baseName.split(separator: " ").first.map(String.init) ?? "User"
        let capitalizedName = firstName.prefix(1).uppercased() + firstName.dropFirst()
        return "\(capitalizedName)'s Space"
    }

    /// Default starter workspace created automatically on initial run.
    public nonisolated static var defaultWorkspace: Workspace {
        Workspace(name: defaultName, sortOrder: 0)
    }
}
