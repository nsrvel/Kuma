import Foundation

/// Thread-safe accumulator that reassembles fragmented TCP/Pipe stream chunks into complete, newline-delimited lines.
/// Solves pipe packet fragmentation where lines are split across read boundaries.
public nonisolated final class LogStreamChunker: @unchecked Sendable {
    private let lock = NSLock()
    private var pendingFragment: String = ""

    public init() {}

    /// Ingests a raw chunk of text, extracts all complete lines, and retains any trailing incomplete fragment.
    ///
    /// - Parameter chunk: The raw string chunk received from stdout/stderr.
    /// - Returns: An array of complete, trimmed lines ready for processing.
    public func ingest(_ chunk: String) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        let combined = pendingFragment + chunk
        let components = combined.components(separatedBy: "\n")

        guard components.count > 1 else {
            // No newline yet; keep entire chunk in fragment buffer
            pendingFragment = combined
            return []
        }

        // All elements except the last are confirmed complete lines
        let completeLines = components.dropLast().compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }

        // The last element is either empty (if chunk ended with \n) or an incomplete fragment
        pendingFragment = components.last ?? ""

        return completeLines
    }

    /// Drains any remaining partial text in the buffer when the process/stream terminates.
    public func flushRemaining() -> String? {
        lock.lock()
        defer { lock.unlock() }

        let remaining = pendingFragment.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingFragment = ""
        return remaining.isEmpty ? nil : remaining
    }
}
