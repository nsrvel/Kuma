import Foundation

/// Global switch for runner → LogAggregator/disk logging. Off during execution refactor; re-enable per provider later.
public enum ServiceExecutionLoggingPolicy {
    nonisolated(unsafe) public static var capturesRunnerOutput = false
}
