import Foundation
import Observation

/// Single in-memory live log stream for the inspector (no disk persistence).
@MainActor
@Observable
public final class LiveLogSession {
    public static let shared = LiveLogSession()

    public private(set) var lines: [LiveLogLine] = []
    /// Service that owns `lines` (set on `start`, kept after `stop` until `clear` or another `start`).
    public private(set) var bufferedServiceID: UUID?
    /// Non-nil while `LiveLogSourceRunner` is attached (inspector log panel + running service only).
    public private(set) var activeServiceID: UUID?
    /// Set when buffer drops oldest lines; UI may show a one-shot notice.
    public private(set) var didTrimToMaxLines: Bool = false

    private let maxLines = 1_000
    private var sourceTask: Task<Void, Never>?
    private var pendingText = ""
    private var flushTask: Task<Void, Never>?

    private init() {}

    public struct LiveLogLine: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let text: String
        public let timestamp: Date

        public init(id: UUID = UUID(), text: String, timestamp: Date = Date()) {
            self.id = id
            self.text = text
            self.timestamp = timestamp
        }
    }

    public func start(serviceID: UUID, service: Service, provider: Provider) {
        stopStreaming()
        bufferedServiceID = serviceID
        activeServiceID = serviceID
        lines = []
        didTrimToMaxLines = false
        pendingText = ""
        sourceTask = Task {
            await LiveLogSourceRunner.run(serviceID: serviceID, service: service, provider: provider) { [weak self] chunk in
                Task { @MainActor in self?.enqueue(chunk) }
            }
        }
    }

    public func stop() {
        stopStreaming()
    }

    public func clear() {
        lines = []
        bufferedServiceID = nil
        didTrimToMaxLines = false
        pendingText = ""
    }

    public func acknowledgeTrimNotice() {
        didTrimToMaxLines = false
    }

    func emitPollerLine(serviceID: UUID, message: String) {
        guard activeServiceID == serviceID else { return }
        enqueue(message)
    }

    internal func testing_bindActiveService(_ serviceID: UUID) {
        activeServiceID = serviceID
        bufferedServiceID = serviceID
    }

    private func stopStreaming() {
        sourceTask?.cancel()
        sourceTask = nil
        flushTask?.cancel()
        flushTask = nil
        flushPendingNow()
        activeServiceID = nil
    }

    internal func testing_ingest(_ text: String) {
        enqueue(text)
        testing_flushPendingNow()
    }

    internal func testing_flushPendingNow() {
        flushPendingNow()
    }

    private func enqueue(_ text: String) {
        pendingText += text
        scheduleFlush()
    }

    private func scheduleFlush() {
        guard flushTask == nil else { return }
        // ponytail: ~30Hz UI coalesce; upgrade path is backpressure on LiveLogSourceRunner
        flushTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 33_000_000)
            flushTask = nil
            flushPendingNow()
            if !pendingText.isEmpty {
                scheduleFlush()
            }
        }
    }

    private func flushPendingNow() {
        guard !pendingText.isEmpty else { return }
        let chunk = pendingText
        pendingText = ""
        appendNow(chunk)
    }

    private func appendNow(_ text: String) {
        let sanitized = ANSISanitizer.sanitize(text)
        for line in sanitized.split(separator: "\n", omittingEmptySubsequences: false) {
            let s = String(line)
            guard !s.isEmpty else { continue }
            lines.append(LiveLogLine(text: s))
        }
        if lines.count > maxLines {
            lines = Array(lines.suffix(maxLines))
            didTrimToMaxLines = true
        }
    }
}
