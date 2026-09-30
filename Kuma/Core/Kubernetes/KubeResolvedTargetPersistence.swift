import Foundation

enum KubeResolvedTargetPersistence {
    /// When discovery picks a concrete resource name, persist it so the inspector shows the live target.
    static func providerApplyingResolvedName(provider: Provider, resolved: KubeResolvedTarget) -> Provider? {
        let trimmed = provider.targetName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty, resolved.name != trimmed else { return nil }

        var updated = provider
        updated.targetName = resolved.name
        if provider.usePattern != false {
            updated.usePattern = false
        }
        updated.updatedAt = Date()
        return updated
    }
}
