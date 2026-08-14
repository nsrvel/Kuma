//
//  KumaStatusBadge.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Reusable status indicator badge with animated colored dot and descriptive label.
//

import SwiftUI

public enum KumaBadgeState: Equatable {
    case available
    case checking
    case notFound
    case custom(color: Color, label: String)

    public var dotColor: Color {
        switch self {
        case .available:
            return KumaColors.statusRunning
        case .checking:
            return KumaColors.statusStarting
        case .notFound:
            return Color.secondary
        case .custom(let color, _):
            return color
        }
    }

    public var text: String {
        switch self {
        case .available:
            return "Available"
        case .checking:
            return "Checking…"
        case .notFound:
            return "Not Found"
        case .custom(_, let label):
            return label
        }
    }
}

public struct KumaStatusBadge: View {
    private let state: KumaBadgeState

    public init(_ state: KumaBadgeState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: KumaSpacing.xs) {
            Circle()
                .fill(state.dotColor)
                .frame(width: 6, height: 6)

            Text(state.text)
                .font(KumaFont.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: KumaSpacing.md) {
        KumaStatusBadge(.available)
        KumaStatusBadge(.checking)
        KumaStatusBadge(.notFound)
        KumaStatusBadge(.custom(color: .purple, label: "Custom State"))
    }
    .padding()
}
