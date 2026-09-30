import XCTest
import SwiftUI
@testable import Kuma

@MainActor
final class AlertServiceTests: XCTestCase {

    func testShowAlertPayload() {
        let alertService = AlertService()
        XCTAssertNil(alertService.activeAlert)

        var primaryCalled = false
        alertService.show(
            title: "Warning",
            message: "Something happened",
            primaryButton: .primary(title: "OK", action: { primaryCalled = true })
        )

        XCTAssertNotNil(alertService.activeAlert)
        XCTAssertEqual(alertService.activeAlert?.title, "Warning")
        XCTAssertEqual(alertService.activeAlert?.message, "Something happened")
        XCTAssertEqual(alertService.activeAlert?.primaryButton.title, "OK")

        alertService.activeAlert?.primaryButton.action?()
        XCTAssertTrue(primaryCalled)

        alertService.dismiss()
        XCTAssertNil(alertService.activeAlert)
    }

    func testConfirmDeletePayload() {
        let alertService = AlertService()
        var deleteConfirmed = false

        alertService.confirmDelete(
            title: "Delete Workspace?",
            message: "All services in “Test” will be deleted.",
            confirmTitle: "Delete",
            onConfirm: { deleteConfirmed = true }
        )

        XCTAssertNotNil(alertService.activeAlert)
        XCTAssertEqual(alertService.activeAlert?.primaryButton.role, .destructive)
        XCTAssertEqual(alertService.activeAlert?.secondaryButton?.role, .cancel)

        alertService.activeAlert?.primaryButton.action?()
        XCTAssertTrue(deleteConfirmed)
    }

    func testShowErrorPayload() {
        let alertService = AlertService()

        alertService.showError(
            title: "Port Conflict",
            message: "Port 5432 is already bound."
        )

        XCTAssertNotNil(alertService.activeAlert)
        XCTAssertEqual(alertService.activeAlert?.title, "Port Conflict")
        XCTAssertNil(alertService.activeAlert?.secondaryButton)
    }
}
