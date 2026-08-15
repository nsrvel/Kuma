import SwiftUI

public struct OnboardingWindowContainerView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    public init() {}

    public var body: some View {
        OnboardingWizardView {
            coordinator.transitionTo(.mainWorkspace)
            openWindow(id: "main-workspace")
            dismissWindow(id: "onboarding")
        }
        .frame(width: 680, height: 500)
    }
}
