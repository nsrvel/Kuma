import SwiftUI

extension ServiceState {
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
}

extension ServiceExecutionState {
    public var color: Color {
        switch self {
        case .idle:     return .secondary
        case .starting: return .yellow
        case .running:  return .green
        case .stopping: return .orange
        case .crashed, .failed: return .red
        }
    }

    public var icon: String {
        switch self {
        case .idle:     return "stop.fill"
        case .starting: return "play.circle.fill"
        case .running:  return "checkmark.circle.fill"
        case .stopping: return "pause.circle.fill"
        case .crashed:  return "exclamationmark.triangle.fill"
        case .failed:   return "xmark.octagon.fill"
        }
    }
}

extension DeckViewMode {
    public var icon: String {
        switch self {
        case .card:  return "square.grid.2x2"
        case .table: return "list.bullet"
        }
    }
}
