//
//  BottomActionButton.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% Pixel-Perfect Match with Kuma V3 BottomActionButton.
//

import SwiftUI

public struct BottomActionButton: View {
    public let title: String
    public let action: () -> Void
    @State private var isHovered = false

    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.primary.opacity(0.8))

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .background(isHovered ? Color.primary.opacity(0.04) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
