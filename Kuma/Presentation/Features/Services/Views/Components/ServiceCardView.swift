import SwiftUI
import AppKit

public struct ServiceCardView: View {
    public let snapshot: ServiceCardSnapshot
    public let runtime: ServiceRuntimeState
    public let isSelected: Bool

    public var onToggle: () -> Void
    public var onSelect: () -> Void

    @State private var isHovered = false
    @State private var isPortHovered: [Int: Bool] = [:]

    public init(
        snapshot: ServiceCardSnapshot,
        runtime: ServiceRuntimeState = ServiceRuntimeState(),
        isSelected: Bool = false,
        onToggle: @escaping () -> Void = {},
        onSelect: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.runtime = runtime
        self.isSelected = isSelected
        self.onToggle = onToggle
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Service Provider Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(snapshot.providerCategory.color.gradient)
                        .frame(width: 34, height: 34)
                        .shadow(color: Color.black.opacity(0.04), radius: 1, y: 0.5)

                    Image(systemName: snapshot.providerCategory.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(snapshot.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(snapshot.isDisabled ? .secondary : .primary)
                            .lineLimit(1)

                        if snapshot.isDisabled {
                            Text("Disabled")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Color.secondary.opacity(0.15), in: Capsule())
                        }
                    }

                    Text(snapshot.subtitle.isEmpty ? snapshot.providerCategory.sidebarLabel : snapshot.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Native macOS Toggle Switch
                if snapshot.isDisabled {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                } else {
                    let isOnBinding = Binding<Bool>(
                        get: { runtime.status == .running || runtime.status == .starting },
                        set: { _ in onToggle() }
                    )
                    Toggle("", isOn: isOnBinding)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .disabled(runtime.isLoading || runtime.status == .starting || runtime.status == .stopping)
                }
            }

            // Port Displays and Live Status Pill
            if !snapshot.portDisplays.isEmpty || runtime.status != .stopped {
                HStack(spacing: 6) {
                    if !snapshot.portDisplays.isEmpty {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)

                        // Clickable Port Chips
                        HStack(spacing: 4) {
                            ForEach(snapshot.portDisplays, id: \.self) { port in
                                Button {
                                    if let url = URL(string: "http://localhost:\(port)") {
                                        NSWorkspace.shared.open(url)
                                    }
                                } label: {
                                    HStack(spacing: 3) {
                                        Text("\(port)")
                                            .font(.system(size: 10, design: .monospaced))
                                        if isPortHovered[port] == true {
                                            Image(systemName: "link")
                                                .font(.system(size: 8))
                                        }
                                    }
                                    .foregroundStyle(isPortHovered[port] == true ? Color.accentColor : Color.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(isPortHovered[port] == true ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                                .onHover { hovering in
                                    isPortHovered[port] = hovering
                                }
                            }
                        }
                    }

                    Spacer()

                    ServiceStatusObserver(state: runtime)
                }
                .padding(.top, 2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .background(Color.primary.opacity(isHovered ? 0.02 : 0.0))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor.opacity(0.8) : (isHovered ? Color.primary.opacity(0.15) : Color.primary.opacity(0.06)),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .shadow(color: .black.opacity(isSelected ? 0.05 : 0.02), radius: isSelected ? 6 : 2, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
