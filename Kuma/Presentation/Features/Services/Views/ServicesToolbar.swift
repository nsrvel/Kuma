//
//  ServicesToolbar.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  100% V3 Pixel-Perfect Toolbar Extension for ServicesDeckView.
//

import SwiftUI

extension ServicesDeckView {
    @ToolbarContentBuilder
    public func toolbarContent() -> some ToolbarContent {
        // 1. Add Service Button (+)
        ToolbarItem {
            Button {
                NotificationCenter.default.post(name: NSNotification.Name("kumaCreateServiceRequested"), object: nil)
            } label: {
                Image(systemName: "plus")
            }
            .help("Add new service")
        }

        // 2. View Mode Segmented Picker (Cards / Table)
        ToolbarItem {
            Picker("View Mode", selection: $viewModel.viewMode) {
                Image(systemName: "square.grid.2x2").tag(DeckViewMode.card)
                Image(systemName: "list.bullet").tag(DeckViewMode.table)
            }
            .pickerStyle(.segmented)
            .help("Switch between card and table view")
        }

        // 3. Filter Menu (Statuses & Providers as Nested Submenus)
        ToolbarItem {
            Menu {
                // Status Submenu
                Menu("Status") {
                    Button {
                        viewModel.selectedStatuses.removeAll()
                    } label: {
                        HStack {
                            Text("All Statuses")
                            if viewModel.selectedStatuses.isEmpty {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Divider()

                    Button {
                        toggleStatusFilter(.running)
                    } label: {
                        HStack {
                            Text("Running")
                            if viewModel.selectedStatuses.contains(.running) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Button {
                        toggleStatusFilter(.stopped)
                    } label: {
                        HStack {
                            Text("Stopped")
                            if viewModel.selectedStatuses.contains(.stopped) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                // Providers Submenu
                Menu("Providers") {
                    Button {
                        viewModel.selectedProviders.removeAll()
                    } label: {
                        HStack {
                            Text("All Providers")
                            if viewModel.selectedProviders.isEmpty {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    Divider()

                    ForEach(ProviderCategory.allCases, id: \.self) { prov in
                        Button {
                            if viewModel.selectedProviders.contains(prov) {
                                viewModel.selectedProviders.remove(prov)
                            } else {
                                viewModel.selectedProviders.insert(prov)
                            }
                        } label: {
                            HStack {
                                Text(prov.sidebarLabel)
                                if viewModel.selectedProviders.contains(prov) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }

                // Reset All Filters (if any active)
                if !viewModel.selectedStatuses.isEmpty || !viewModel.selectedProviders.isEmpty {
                    Divider()

                    Button("Reset All Filters") {
                        viewModel.selectedStatuses.removeAll()
                        viewModel.selectedProviders.removeAll()
                    }
                }
            } label: {
                Image(systemName: (!viewModel.selectedStatuses.isEmpty || !viewModel.selectedProviders.isEmpty) ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
            }
            .menuIndicator(.hidden)
            .help("Filter services")
        }

        // 4. Sort Menu (Name, Status, Created)
        ToolbarItem {
            Menu {
                ForEach(ServiceSortOption.allCases, id: \.self) { sortOpt in
                    Button {
                        viewModel.sortBy = sortOpt
                    } label: {
                        HStack {
                            Text(sortOpt.rawValue)
                            if viewModel.sortBy == sortOpt {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .menuIndicator(.hidden)
            .help("Sort services")
        }

        // 5. Actions Ellipsis Menu (Start All, Stop All, Import, Export)
        ToolbarItem {
            Menu {
                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("kumaCreateServiceRequested"), object: nil)
                } label: {
                    Label("Add New Service", systemImage: "plus")
                }

                Button {
                    for service in viewModel.services {
                        viewModel.serviceStates[service.id] = .running
                    }
                } label: {
                    Label("Start All", systemImage: "play.fill")
                }

                Button {
                    for service in viewModel.services {
                        viewModel.serviceStates[service.id] = .stopped
                    }
                } label: {
                    Label("Stop All", systemImage: "stop.fill")
                }

                Divider()

                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("kumaImportWorkspace"), object: nil)
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }

                Button {
                    NotificationCenter.default.post(name: NSNotification.Name("kumaExportWorkspace"), object: nil)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuIndicator(.hidden)
            .help("More actions")
        }

        // 6. Native Trailing Sidebar Toggle
        ToolbarItem {
            Button {
                viewModel.isInspectorPresented.toggle()
            } label: {
                Image(systemName: "sidebar.trailing")
            }
            .help(viewModel.isInspectorPresented ? "Hide detail panel" : "Show detail panel")
        }
    }

    private func toggleStatusFilter(_ state: ServiceState) {
        if viewModel.selectedStatuses.contains(state) {
            viewModel.selectedStatuses.remove(state)
        } else {
            viewModel.selectedStatuses.insert(state)
        }
    }
}
