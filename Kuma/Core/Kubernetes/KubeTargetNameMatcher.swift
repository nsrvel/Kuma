import Foundation

enum KubeTargetNameMatcher {
    /// Picks the first match from **lexicographically sorted** `names` (caller should sort).
    /// - Wildcard (`*`): substring match on the pattern with stars removed.
    /// - Otherwise: exact name, or (pods only) a running pod named `<pattern>-<replica-suffix>`.
    nonisolated static func firstMatch(
        pattern: String,
        in names: [String],
        allowPodReplicaPrefix: Bool = false
    ) -> String? {
        let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPattern.isEmpty else { return nil }

        let sorted = names.sorted()
        if trimmedPattern.contains("*") {
            let cleanedPattern = trimmedPattern.replacingOccurrences(of: "*", with: "")
            guard !cleanedPattern.isEmpty else { return sorted.first }
            return sorted.first { name in
                name.localizedCaseInsensitiveContains(cleanedPattern)
            }
        }

        if let exact = sorted.first(where: { $0 == trimmedPattern }) {
            return exact
        }

        guard allowPodReplicaPrefix else { return nil }

        let prefix = trimmedPattern + "-"
        return sorted.first { $0.hasPrefix(prefix) }
    }
}
