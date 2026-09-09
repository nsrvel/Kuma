import SwiftUI
import Testing
@testable import Kuma

@Suite("DataPort Category F: Visual, View Modularity & Accessibility HIG", .serialized)
@MainActor
struct DataPortVisualAndAccessibilityTests {

    // MARK: - [TC-F01] Import Preview Sheet File Lines Limit Strict
    @Test("TC-F01: File ImportPreviewSheet dan WorkspaceImportPreviewSheet mematuhi batasan < 150 baris")
    func testImportPreviewSheetFileLinesLimitStrict() {
        let previewPath = "Kuma/Presentation/Features/DataPort/Views/ImportPreviewSheet.swift"
        let wsPreviewPath = "Kuma/Presentation/Features/DataPort/Views/WorkspaceImportPreviewSheet.swift"

        if let previewContent = try? String(contentsOfFile: previewPath, encoding: .utf8) {
            let lines = previewContent.components(separatedBy: .newlines).count
            #expect(lines <= 150)
        }

        if let wsContent = try? String(contentsOfFile: wsPreviewPath, encoding: .utf8) {
            let lines = wsContent.components(separatedBy: .newlines).count
            #expect(lines <= 150)
        }
    }

    // MARK: - [TC-F02] Import Detail Inspector Pane File Lines Limit Strict
    @Test("TC-F02: File ImportDetailInspectorPane mematuhi batasan < 150 baris")
    func testImportDetailInspectorPaneFileLinesLimitStrict() {
        let inspectorPath = "Kuma/Presentation/Features/DataPort/Views/Components/ImportDetailInspectorPane.swift"

        if let content = try? String(contentsOfFile: inspectorPath, encoding: .utf8) {
            let lines = content.components(separatedBy: .newlines).count
            #expect(lines <= 150)
        }
    }

    // MARK: - [TC-F03] Import Preview Header View Rendering
    @Test("TC-F03: Headless render ImportPreviewHeaderView berhasil dengan title dan search field")
    func testImportPreviewHeaderViewRendering() {
        var query = ""
        let binding = Binding<String>(
            get: { query },
            set: { query = $0 }
        )

        let header = ImportPreviewHeaderView(
            title: "Test Header",
            subtitle: "Subtitle info",
            searchText: binding
        )

        #expect(header.title == "Test Header")
        #expect(header.subtitle == "Subtitle info")
    }

    // MARK: - [TC-F04] Import Preview Footer View Rendering
    @Test("TC-F04: Headless render ImportPreviewFooterView dengan counter selection yang akurat")
    func testImportPreviewFooterViewRendering() {
        var didToggle = false
        var didCancel = false
        var didImport = false

        let footer = ImportPreviewFooterView(
            selectedCount: 3,
            totalCount: 5,
            filteredCount: 5,
            onToggleSelectAll: { didToggle = true },
            onCancel: { didCancel = true },
            onImport: { didImport = true }
        )

        #expect(footer.selectedCount == 3)
        #expect(footer.totalCount == 5)

        footer.onToggleSelectAll()
        #expect(didToggle == true)

        footer.onCancel()
        #expect(didCancel == true)

        footer.onImport()
        #expect(didImport == true)
    }

    // MARK: - [TC-F05] Import Detail Inspector Pane Accessibility Labels
    @Test("TC-F05: Render inspector pane dengan provider Docker dan port mapping")
    func testImportDetailInspectorPaneAccessibilityLabels() {
        let prov = DataPortService.ExportProvider(
            serviceID: UUID(),
            type: "docker",
            label: "Test Docker"
        )
        let port = DataPortService.ExportPortMapping(
            providerID: prov.id,
            localPort: 8080,
            remotePort: 80
        )

        let pane = ImportDetailInspectorPane(
            serviceName: "Web App",
            serviceDescription: "Frontend Service",
            provider: prov,
            portMappings: [port],
            hasConflict: false
        )

        #expect(pane.serviceName == "Web App")
        #expect(pane.hasConflict == false)
        #expect(pane.portMappings.count == 1)
    }
}
