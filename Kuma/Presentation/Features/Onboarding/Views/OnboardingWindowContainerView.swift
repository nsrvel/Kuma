//
//  OnboardingWindowContainerView.swift
//  Kuma
//
//  Created for Kuma Native macOS App.
//  Container managing the dismissal of Onboarding Window and transition to Main Workspace.
//

import SwiftUI

public struct OnboardingWindowContainerView: View {
    @AppStorage("kuma.has_completed_onboarding") private var hasCompletedOnboarding: Bool = false
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    public init() {}

    public var body: some View {
        OnboardingWizardView {
            hasCompletedOnboarding = true
            openWindow(id: "main-workspace")
            dismissWindow(id: "onboarding")
        }
        .frame(width: 680, height: 500)
    }
}
