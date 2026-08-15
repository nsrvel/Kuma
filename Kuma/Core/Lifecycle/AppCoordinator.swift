import Foundation
import Observation
import os

public enum AppPhase: String, Sendable, Equatable {
    case onboarding
    case mainWorkspace
}

@MainActor
@Observable
public final class AppCoordinator {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "AppCoordinator")

    public private(set) var currentPhase: AppPhase

    public init(initialPhase: AppPhase? = nil) {
        if let initialPhase {
            self.currentPhase = initialPhase
        } else {
            let hasCompleted = UserDefaults.standard.bool(forKey: "kuma.has_completed_onboarding")
            self.currentPhase = hasCompleted ? .mainWorkspace : .onboarding
        }
        Self.logger.debug("AppCoordinator initialized with phase: \(self.currentPhase.rawValue)")
    }

    /// Transitions to a new phase and persists completed onboarding state when moving to mainWorkspace.
    public func transitionTo(_ phase: AppPhase) {
        Self.logger.info("Transitioning AppPhase to: \(phase.rawValue)")
        self.currentPhase = phase
        if phase == .mainWorkspace {
            UserDefaults.standard.set(true, forKey: "kuma.has_completed_onboarding")
        }
    }

    /// Triggers onboarding from menu bar / help menu.
    public func resetToOnboarding() {
        Self.logger.info("Resetting phase to onboarding")
        self.currentPhase = .onboarding
    }
}
