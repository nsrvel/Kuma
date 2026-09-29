import Foundation

enum KubeTargetNamingHints {
    /// Heuristic: pod names usually end with a ReplicaSet + pod hash (e.g. `my-app-7d4f9b2c3d-8nn4d`).
    static func looksLikeStableWorkloadName(_ name: String) -> Bool {
        let parts = name.split(separator: "-")
        guard let last = parts.last else { return false }
        let suffix = String(last)
        if suffix.lowercased() == "pod" { return false }
        if suffix.count >= 5, suffix.allSatisfy({ $0.isLetter || $0.isNumber }) {
            return false
        }
        return parts.count >= 2
    }
}
