//
//  SingleInstanceGuardTests.swift
//  KumaTests
//
//  Created for Kuma Native macOS App.
//

import Testing
@testable import Kuma

@Suite("Lifecycle Tests: SingleInstanceGuard")
struct SingleInstanceGuardTests {

    @Test("SingleInstanceGuard handles same process without self-termination")
    @MainActor
    func testSingleInstanceRunningCheck() {
        // When running in test process, there is only one instance with test bundle ID
        let hasOtherInstance = SingleInstanceGuard.activateExistingInstanceIfRunning()
        #expect(hasOtherInstance == false)
    }
}
