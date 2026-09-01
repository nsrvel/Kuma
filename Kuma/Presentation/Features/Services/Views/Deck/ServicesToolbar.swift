import SwiftUI

extension ServicesDeckView {
    @ToolbarContentBuilder
    public func toolbarContent() -> some ToolbarContent {
        // 1. Add Service Button (+)
        ToolbarItem {
            Button {
                NotificationCenter.default.post(name: .kumaCreateServiceRequested, object: nil)
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add Service")
            .accessibilityHint("Opens creation sheet to add a new service")
            .help("Add new service")
        }

        // 2. View Mode Segmented Picker (Cards / Table)
        ToolbarItem {
            Picker("View Mode", selection: $viewModel.viewMode) {
                Image(systemName: "square.grid.2x2")
                    .accessibilityLabel("Grid View")
                    .tag(DeckViewMode.card)
                Image(systemName: "list.bullet")
                    .accessibilityLabel("Table View")
                    .tag(DeckViewMode.table)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Deck View Mode")
            .help("Switch between card and table view")
        }

        // 3. Filter Menu (Pure macOS HIG: Sections + Native Toggles)
        ToolbarItem {
            Menu {
                Section("Status") {
                    Toggle("Running", isOn: Binding(
                        get: { viewModel.selectedStatuses.contains(.running) },
                        set: { _ in toggleStatusFilter(.running) }
                    ))

                    Toggle("Stopped", isOn: Binding(
                        get: { viewModel.selectedStatuses.contains(.stopped) },
                        set: { _ in toggleStatusFilter(.stopped) }
                    ))

                    Toggle("Crashed", isOn: Binding(
                        get: { viewModel.selectedStatuses.contains(.crashed) },
                        set: { _ in toggleStatusFilter(.crashed) }
                    ))

                    Toggle("Disabled", isOn: Binding(
                        get: { viewModel.selectedStatuses.contains(.disabled) },
                        set: { _ in toggleStatusFilter(.disabled) }
                    ))
                }

                Section("Provider") {
                    ForEach(ProviderCategory.allCases, id: \.self) { prov in
                        Toggle(prov.sidebarLabel, isOn: Binding(
                            get: { viewModel.selectedProviders.contains(prov) },
                            set: { _ in toggleProviderFilter(prov) }
                        ))
                    }
                }

                if !viewModel.selectedStatuses.isEmpty || !viewModel.selectedProviders.isEmpty {
                    Divider()

                    Button("Reset Filters") {
                        viewModel.selectedStatuses.removeAll()
                        viewModel.selectedProviders.removeAll()
                    }
                }
            } label: {
                Image(systemName: (!viewModel.selectedStatuses.isEmpty || !viewModel.selectedProviders.isEmpty) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
            }
            .menuIndicator(.hidden)
            .accessibilityLabel("Filter Services")
            .accessibilityHint("Filters services by status or provider type")
            .help("Filter services")
        }

        // 4. Sort Menu (Pure macOS HIG: Section + Native Radio Toggles)
        ToolbarItem {
            Menu {
                Section("Sort By") {
                    ForEach(ServiceSortOption.allCases, id: \.self) { sortOpt in
                        Toggle(sortOpt.rawValue, isOn: Binding(
                            get: { viewModel.sortBy == sortOpt },
                            set: { if $0 { viewModel.sortBy = sortOpt } }
                        ))
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuIndicator(.hidden)
            .accessibilityLabel("Sort Services")
            .accessibilityHint("Sorts services by name, status, or date")
            .help("Sort services")
        }

        // 5. Actions Ellipsis Menu (Start All, Stop All, Import, Export)
        ToolbarItem {
            Menu {
                Button {
                    NotificationCenter.default.post(name: .kumaCreateServiceRequested, object: nil)
                } label: {
                    Label("Add New Service", systemImage: "plus")
                }

                Button {
                    for snapshot in viewModel.snapshots {
                        viewModel.runtimeStates[snapshot.id] = ServiceRuntimeState(status: .running, isLoading: false)
                    }
                } label: {
                    Label("Start All", systemImage: "play.fill")
                }

                Button {
                    for snapshot in viewModel.snapshots {
                        viewModel.runtimeStates[snapshot.id] = ServiceRuntimeState(status: .stopped, isLoading: false)
                    }
                } label: {
                    Label("Stop All", systemImage: "stop.fill")
                }

                Divider()

                Button {
                    NotificationCenter.default.post(name: .kumaImportWorkspace, object: nil)
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

                Button {
                    NotificationCenter.default.post(name: .kumaExportWorkspace, object: nil)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuIndicator(.hidden)
            .accessibilityLabel("More Workspace Actions")
            .accessibilityHint("Offers bulk actions, import and export options")
            .help("More actions")
        }

        // 6. Native Trailing Sidebar Toggle
        ToolbarItem {
            Button {
                viewModel.isInspectorPresented.toggle()
            } label: {
                Image(systemName: "sidebar.trailing")
            }
            .help(viewModel.isInspectorPresented ? "Hide detail panel (⌘I)" : "Show detail panel (⌘I)")
            .keyboardShortcut("i", modifiers: [.command])
        }
    }

    private func toggleStatusFilter(_ state: ServiceStatusFilterOption) {
        if viewModel.selectedStatuses.contains(state) {
            viewModel.selectedStatuses.remove(state)
        } else {
            viewModel.selectedStatuses.insert(state)
        }
    }

    private func toggleProviderFilter(_ prov: ProviderCategory) {
        if viewModel.selectedProviders.contains(prov) {
            viewModel.selectedProviders.remove(prov)
        } else {
            viewModel.selectedProviders.insert(prov)
        }
    }
}
