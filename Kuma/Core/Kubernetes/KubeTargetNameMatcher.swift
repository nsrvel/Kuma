import Foundation

enum KubeTargetNameMatcher {
    nonisolated static func firstMatch(pattern: String, in names: [String]) -> String? {
        let trimmedPattern = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPattern.isEmpty else { return nil }

        let cleanedPattern = trimmedPattern.replacingOccurrences(of: "*", with: "")
        return names.first { name in
            if trimmedPattern.contains("*") {
                return name.localizedCaseInsensitiveContains(cleanedPattern)
            }
            return name == trimmedPattern
                || name.hasPrefix(trimmedPattern)
                || name.localizedCaseInsensitiveContains(trimmedPattern)
        }
    }
}
