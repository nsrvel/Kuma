import SwiftUI

/// Sidebar Live Logs shell — streaming is per-service in the Inspector.
public struct LiveLogsView: View {
    @State private var filterQuery: String = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                KumaSearchField(text: $filterQuery, prompt: "Filter logs…")
                    .frame(maxWidth: 320)
                    .disabled(true)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(KumaColors.canvasBackground)

            Divider().opacity(0.4)

            ZStack {
                Color.black.opacity(0.85)
                KumaEmptyStateView(
                    iconName: "terminal",
                    title: "No live logs here",
                    description: "Live logs are available per service in the Inspector."
                )
            }
        }
        .navigationTitle("Live Logs")
        .background(KumaColors.canvasBackground)
    }
}
