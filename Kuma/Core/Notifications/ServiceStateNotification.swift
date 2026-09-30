import Foundation

/// Canonical payload for `.kumaServiceStateChanged` notifications.
public enum ServiceStateNotification {
    public static let stateKey = "state"
    public static let pidKey = "pid"
    public static let exitCodeKey = "exitCode"

    @MainActor
    public static func post(
        serviceID: UUID,
        state: ServiceState,
        pid: Int32? = nil,
        exitCode: Int32? = nil
    ) {
        var userInfo: [String: Any] = [stateKey: state]
        if let pid {
            userInfo[pidKey] = pid
        }
        if let exitCode {
            userInfo[exitCodeKey] = exitCode
        }
        NotificationCenter.default.post(
            name: .kumaServiceStateChanged,
            object: serviceID,
            userInfo: userInfo
        )
    }

    public static func executionState(
        from userInfo: [AnyHashable: Any]?,
        existing: ServiceExecutionState
    ) -> ServiceExecutionState? {
        guard let userInfo,
              let state = userInfo[stateKey] as? ServiceState else { return nil }

        switch state {
        case .stopped:
            return .idle
        case .starting:
            return .starting
        case .running:
            let pid = int32(in: userInfo, key: pidKey)
                ?? existing.processIdentifier
                ?? 0
            return .running(pid: pid)
        case .stopping:
            return .stopping
        case .crashed:
            if let code = int32(in: userInfo, key: exitCodeKey) {
                return .crashed(exitCode: code)
            }
            if case .crashed(let existingCode) = existing {
                return .crashed(exitCode: existingCode)
            }
            return .crashed(exitCode: 1)
        }
    }

    private static func int32(in userInfo: [AnyHashable: Any], key: String) -> Int32? {
        if let value = userInfo[key] as? Int32 { return value }
        if let value = userInfo[key] as? Int { return Int32(value) }
        return nil
    }
}
