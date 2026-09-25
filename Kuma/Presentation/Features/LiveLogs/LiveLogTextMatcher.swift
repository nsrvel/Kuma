import Foundation

/// Substring or `/pattern/` regex matching for live log filters.
public enum LiveLogTextMatcher {
    public static func matches(_ text: String, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let haystack = text.lowercased()

        if trimmed.hasPrefix("/"), trimmed.hasSuffix("/"), trimmed.count > 2 {
            let pattern = String(trimmed.dropFirst().dropLast())
            guard !pattern.isEmpty else { return haystack.contains(trimmed.lowercased()) }
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(haystack.startIndex..., in: haystack)
                return regex.firstMatch(in: haystack, options: [], range: range) != nil
            }
            // ponytail: invalid regex falls back to substring — upgrade path: show inline validation in UI
            return haystack.contains(pattern.lowercased())
        }

        return haystack.contains(trimmed.lowercased())
    }
}
