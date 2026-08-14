//
//  OnboardingViewModelTests.swift
//  KumaTests
//
//  Created for Kuma Native macOS App.
//

import Testing
@testable import Kuma

@Suite("Onboarding ViewModel Tests")
@MainActor
struct OnboardingViewModelTests {

    @Test("OnboardingViewModel initial state")
    func testInitialState() {
        let viewModel = OnboardingViewModel()
        #expect(viewModel.currentStep == 0)
        #expect(viewModel.totalSteps == 4)
        #expect(viewModel.isScanning == false)
        #expect(viewModel.hasInitialScanned == false)
    }

    @Test("OnboardingViewModel step navigation boundaries")
    func testStepNavigation() {
        let viewModel = OnboardingViewModel()

        // Test nextStep increments
        viewModel.nextStep()
        #expect(viewModel.currentStep == 1)

        viewModel.nextStep()
        #expect(viewModel.currentStep == 2)

        viewModel.nextStep()
        #expect(viewModel.currentStep == 3)

        // Cannot exceed max step
        viewModel.nextStep()
        #expect(viewModel.currentStep == 3)

        // Test prevStep decrements
        viewModel.prevStep()
        #expect(viewModel.currentStep == 2)

        viewModel.prevStep()
        #expect(viewModel.currentStep == 1)

        viewModel.prevStep()
        #expect(viewModel.currentStep == 0)

        // Cannot go below step 0
        viewModel.prevStep()
        #expect(viewModel.currentStep == 0)
    }

    @Test("OnboardingViewModel lazy scan population")
    func testScanDependencies() async {
        let viewModel = OnboardingViewModel()
        await viewModel.scanDependenciesIfNeeded()

        #expect(viewModel.hasInitialScanned == true)
        #expect(viewModel.engineDependencies.count == 4)
        #expect(viewModel.tunnelingDependencies.count == 2)
        #expect(viewModel.isScanning == false)
    }
}
