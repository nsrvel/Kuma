import SwiftUI

public struct ProviderBrandIcon: View {
    public let category: ProviderCategory
    public var tunnelType: String? = nil
    public var size: CGFloat = 14

    public init(category: ProviderCategory, tunnelType: String? = nil, size: CGFloat = 14) {
        self.category = category
        self.tunnelType = tunnelType
        self.size = size
    }

    public var body: some View {
        Group {
            switch category {
            case .docker:
                DockerBrandVector()
                    .frame(width: size, height: size)
            case .kubernetes:
                KubernetesBrandVector()
                    .frame(width: size, height: size)
            case .podman:
                PodmanBrandVector()
                    .frame(width: size, height: size)
            case .shell:
                Image(systemName: "terminal.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            case .ssh:
                Image(systemName: "server.rack")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            case .httpCheck:
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            case .tunnel:
                Image(systemName: "cloud.bolt.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            case .processMonitor:
                Image(systemName: "cpu.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        }
    }
}
