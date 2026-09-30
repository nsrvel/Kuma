import Foundation

/// High-performance stream pipeline for an active service.
/// Connects pipe chunk reassembly, ANSI sanitization, UI batch dispatching, and disk log persistence.
public actor ServiceLogPipeline {
    public let serviceID: UUID
    public let serviceName: String

    private let chunker = LogStreamChunker()
    private var pendingBatch: [LiveLogEntry] = []
    private var flushTask: Task<Void, Never>? = nil
    private var pendingRawChunks: [(chunk: String, level: String)] = []

    private let flushIntervalNanoseconds: UInt64 = 33_000_000 // ~30Hz (33ms) cadenced UI dispatch
    private let maxBatchSize = 30

    public init(serviceID: UUID, serviceName: String) {
        self.serviceID = serviceID
        self.serviceName = serviceName
    }

    /// Primary entry point for stdout/stderr raw chunks from subprocesses.
    public func ingestRawChunk(_ chunk: String, level: String = "INFO") {
        ingestRawChunkImpl(chunk, level: level)
    }

    private func ingestRawChunkImpl(_ chunk: String, level: String = "INFO") {
        let completeLines = chunker.ingest(chunk)
        guard !completeLines.isEmpty else { return }

        let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        for rawLine in completeLines {
            let sanitized = ANSISanitizer.sanitize(rawLine)
            guard !sanitized.isEmpty else { continue }

            let entry = LiveLogEntry(
                serviceID: serviceID,
                serviceName: serviceName,
                timestamp: now,
                level: level,
                message: sanitized
            )
            pendingBatch.append(entry)
        }

        if pendingBatch.count >= maxBatchSize {
            flushTask?.cancel()
            flushTask = nil
            flushBatch()
        } else if flushTask == nil {
            scheduleFlush()
        }
    }

    /// Emits a single structured log line directly (e.g. from HealthCheckRunner, TunnelRunner, or system notices).
    public func emit(level: String = "INFO", message: String) {
        let sanitized = ANSISanitizer.sanitize(message)
        guard !sanitized.isEmpty else { return }

        let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let entry = LiveLogEntry(
            serviceID: serviceID,
            serviceName: serviceName,
            timestamp: now,
            level: level,
            message: sanitized
        )
        pendingBatch.append(entry)

        if pendingBatch.count >= maxBatchSize {
            flushTask?.cancel()
            flushTask = nil
            flushBatch()
        } else if flushTask == nil {
            scheduleFlush()
        }
    }

    private func scheduleFlush() {
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.flushIntervalNanoseconds ?? 33_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.flushBatch()
        }
    }

    private func flushBatch() {
        flushTask = nil
        guard !pendingBatch.isEmpty else { return }

        let batch = pendingBatch
        pendingBatch.removeAll(keepingCapacity: true)

        // 1. Hot path: UI batch only when a live-log surface is subscribed
        Task { @MainActor in
            let aggregator = LogAggregator.shared
            if aggregator.deliversToUI {
                aggregator.appendBatch(batch)
            }
        }

        // 2. Cold path: Single batch append to disk LogFileWriter
        let diskItems = batch.map { (level: $0.level, message: $0.message) }
        Task {
            await LogFileWriter.shared.appendBatch(serviceID: serviceID, items: diskItems)
        }
    }

    /// Drains any remaining partial fragments and pending batches (e.g. when subprocess terminates).
    public func finish() {
        flushTask?.cancel()
        flushTask = nil
        drainPendingRawChunks()

        if let trailing = chunker.flushRemaining() {
            let sanitized = ANSISanitizer.sanitize(trailing)
            if !sanitized.isEmpty {
                let now = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
                pendingBatch.append(LiveLogEntry(
                    serviceID: serviceID,
                    serviceName: serviceName,
                    timestamp: now,
                    level: "INFO",
                    message: sanitized
                ))
            }
        }

        flushBatch()
    }

    private func enqueueRawChunk(_ chunk: String, level: String = "INFO") {
        pendingRawChunks.append((chunk, level))
        drainPendingRawChunks()
    }

    private func drainPendingRawChunks() {
        while !pendingRawChunks.isEmpty {
            let item = pendingRawChunks.removeFirst()
            ingestRawChunkImpl(item.chunk, level: item.level)
        }
    }

    /// Creates a thread-safe `@Sendable` closure wrapping chunk ingestion.
    public nonisolated func makeOutputHandler() -> @Sendable (String) -> Void {
        return { [weak self] text in
            Task { [weak self] in
                await self?.enqueueRawChunk(text)
            }
        }
    }
}
