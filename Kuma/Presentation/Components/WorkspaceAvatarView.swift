//
//  WorkspaceAvatarView.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Dynamic color avatar squircle generating deterministic gradients and initials.
//

import SwiftUI
import AppKit

public struct WorkspaceAvatarView: View {
    public let name: String
    public let imagePath: String?
    public let size: CGFloat

    private static let imageCache = NSCache<NSString, NSImage>()

    public init(name: String, imagePath: String? = nil, size: CGFloat = 24) {
        self.name = name
        self.imagePath = imagePath
        self.size = size
    }

    public init(workspace: Workspace, size: CGFloat = 24) {
        self.init(name: workspace.name, imagePath: workspace.imagePath, size: size)
    }

    public var body: some View {
        ZStack {
            if let imgPath = imagePath, let nsImg = cachedImage(from: imgPath) {
                Image(nsImage: nsImg)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(avatarGradient)

                Text(initials)
                    .font(.system(size: size * 0.44, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }

    private func cachedImage(from path: String) -> NSImage? {
        let key = path as NSString
        if let cached = Self.imageCache.object(forKey: key) {
            return cached
        }
        if let img = NSImage(contentsOfFile: path) {
            Self.imageCache.setObject(img, forKey: key)
            return img
        }
        return nil
    }

    private var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "W" }
        let words = trimmed.split(separator: " ")
        if let first = words.first?.first {
            return String(first).uppercased()
        }
        return "W"
    }

    private var avatarGradient: LinearGradient {
        let hash = abs(name.utf8.reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) })
        let palettes: [[Color]] = [
            [Color(red: 0.18, green: 0.48, blue: 0.96), Color(red: 0.35, green: 0.65, blue: 1.00)], // Blue
            [Color(red: 0.85, green: 0.18, blue: 0.85), Color(red: 0.95, green: 0.45, blue: 0.95)], // Pink/Purple
            [Color(red: 0.05, green: 0.75, blue: 0.45), Color(red: 0.25, green: 0.95, blue: 0.65)], // Green
            [Color(red: 0.95, green: 0.36, blue: 0.13), Color(red: 1.00, green: 0.60, blue: 0.30)], // Orange
            [Color(red: 0.58, green: 0.18, blue: 0.95), Color(red: 0.78, green: 0.45, blue: 1.00)]  // Indigo
        ]
        let colors = palettes[hash % palettes.count]
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview {
    HStack(spacing: 12) {
        WorkspaceAvatarView(name: "Default Workspace", size: 32)
        WorkspaceAvatarView(name: "Production Backend", size: 32)
        WorkspaceAvatarView(name: "Staging Cluster", size: 32)
        WorkspaceAvatarView(name: "Analytics Service", size: 32)
    }
    .padding()
}
