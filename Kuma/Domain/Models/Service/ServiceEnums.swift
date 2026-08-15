import SwiftUI

// MARK: - Service State

public enum ServiceState: String, Codable, Sendable, CaseIterable {
    case stopped
    case starting
    case running
    case stopping
    case crashed

    public var title: String {
        switch self {
        case .stopped:  return "Stopped"
        case .starting: return "Starting"
        case .running:  return "Running"
        case .stopping: return "Stopping"
        case .crashed:  return "Crashed"
        }
    }

    public var color: Color {
        switch self {
        case .stopped:  return .secondary
        case .starting: return .yellow
        case .running:  return .green
        case .stopping: return .orange
        case .crashed:  return .red
        }
    }

    public var icon: String {
        switch self {
        case .stopped:  return "stop.fill"
        case .starting: return "play.circle.fill"
        case .running:  return "checkmark.circle.fill"
        case .stopping: return "pause.circle.fill"
        case .crashed:  return "exclamationmark.triangle.fill"
        }
    }

    public var isOperational: Bool {
        self == .running || self == .starting
    }

    /// Natural status sorting priority (Running > Starting > Stopping > Crashed > Stopped)
    public var sortPriority: Int {
        switch self {
        case .running:  return 0
        case .starting: return 1
        case .stopping: return 2
        case .crashed:  return 3
        case .stopped:  return 4
        }
    }
}

// MARK: - Deck View Mode

public enum DeckViewMode: String, Codable, Sendable, CaseIterable {
    case card
    case table

    public var icon: String {
        switch self {
        case .card:  return "square.grid.2x2"
        case .table: return "list.bullet"
        }
    }
}

// MARK: - Service Sort Option

public enum ServiceSortOption: String, Codable, Sendable, CaseIterable {
    case name = "Name"
    case status = "Status"
    case created = "Date Created"
}
