//
//  AppCoordinatorTests.swift
//  KumaTests
//
//  Created for Kuma Native macOS App.
//

import Testing
@testable import Kuma

@Suite("Lifecycle Tests: AppCoordinator")
@MainActor
struct AppCoordinatorTests {

    @Test("AppCoordinator initializes with provided phase")
    func testAppCoordinatorInitialization() {
        let coordinator = AppCoordinator(initialPhase: .onboarding)
        #expect(coordinator.currentPhase == .onboarding)

        coordinator.transitionTo(.mainWorkspace)
        #expect(coordinator.currentPhase == .mainWorkspace)

        coordinator.resetToOnboarding()
        #expect(coordinator.currentPhase == .onboarding)
    }
}
