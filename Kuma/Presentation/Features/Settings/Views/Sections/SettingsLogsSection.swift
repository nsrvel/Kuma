//
//  SettingsLogsSection.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% V3 Pixel-Perfect Logs Section.
//

import SwiftUI

public struct SettingsLogsSection: View {
    @Bindable var store: SettingsStore

    public init(store: SettingsStore) {
        self.store = store
    }

    public var body: some View {
        KumaFormSection(
            icon: "doc.text.fill",
            title: "Logs & Buffer"
        ) {
            VStack(alignment: .leading, spacing: KumaSpacing.lg) {
                KumaRowPickerField(
                    label: "Max Log Buffer in Memory",
                    description: "Maximum memory buffer kept per running service inspector.",
                    options: LogRetentionLimit.allCases,
                    selection: $store.logRetentionLimit,
                    titleResolver: { $0.title }
                )

                Divider().opacity(0.3)

                KumaToggleField(
                    label: "Clear Buffer on Service Restart",
                    value: $store.clearLogsOnSwitch,
                    description: "Flush previous console output when triggering a service restart."
                )
            }
        }
    }
}
