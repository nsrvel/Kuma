import SwiftUI

public struct SidebarDropIndicator: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 5, height: 5)
                .offset(x: 2)

            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 2)
        }
        .padding(.horizontal, 6)
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}
