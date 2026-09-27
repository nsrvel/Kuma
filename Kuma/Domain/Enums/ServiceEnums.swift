import Foundation

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
