//
//  SettingsGeneralSection.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% V3 Pixel-Perfect General Section.
//

import SwiftUI

public struct SettingsGeneralSection: View {
    @Bindable var store: SettingsStore

    public init(store: SettingsStore) {
        self.store = store
    }

    public var body: some View {
        KumaFormSection(
            icon: "gearshape.fill",
            title: "General"
        ) {
            VStack(alignment: .leading, spacing: KumaSpacing.lg) {
                KumaToggleField(
                    label: "Launch at Login",
                    value: $store.launchAtLogin,
                    description: "Automatically open Kuma when you log into your Mac."
                )

                Divider().opacity(0.3)

                KumaToggleField(
                    label: "Auto-start Services",
                    value: $store.autoResumeServices,
                    description: "Automatically resume services that were active when Kuma was last quit."
                )

                Divider().opacity(0.3)

                KumaToggleField(
                    label: "Confirm Before Quitting",
                    value: $store.confirmBeforeQuit,
                    description: "Show a confirmation prompt when quitting Kuma while services are running."
                )
            }
        }
    }
}
