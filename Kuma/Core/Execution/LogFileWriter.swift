import Foundation
import os

/// High-throughput cold-path file logger.
/// Batches incoming stdout/stderr lines and asynchronously writes to disk without blocking execution.
public actor LogFileWriter {
    public static let shared = LogFileWriter()
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "LogFileWriter")

    private struct QueuedLog: Sendable {
        let serviceID: UUID
        let timestamp: Date
        let level: String
        let message: String
    }

    private var buffer: [QueuedLog] = []
    private var flushTask: Task<Void, Never>? = nil
    private let maxBufferSize = 50
    private let flushIntervalNanoseconds: UInt64 = 250_000_000 // 250ms

    private let logsDirectory: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let kumaLogs = appSupport.appendingPathComponent("Kuma", isDirectory: true).appendingPathComponent("Logs", isDirectory: true)
        self.logsDirectory = kumaLogs

        try? FileManager.default.createDirectory(at: kumaLogs, withIntermediateDirectories: true)
    }

    /// Appends a new log line to the cold storage buffer.
    public func append(serviceID: UUID, level: String = "INFO", message: String) {
        let item = QueuedLog(serviceID: serviceID, timestamp: Date(), level: level, message: message)
        buffer.append(item)

        if buffer.count >= maxBufferSize {
            flushTask?.cancel()
            flushTask = nil
            flushBuffer()
        } else if flushTask == nil {
            scheduleFlush()
        }
    }

    /// Appends multiple log lines directly to the cold storage buffer.
    public func appendBatch(serviceID: UUID, items: [(level: String, message: String)]) {
        guard !items.isEmpty else { return }
        let now = Date()
        for item in items {
            buffer.append(QueuedLog(serviceID: serviceID, timestamp: now, level: item.level, message: item.message))
        }

        if buffer.count >= maxBufferSize {
            flushTask?.cancel()
            flushTask = nil
            flushBuffer()
        } else if flushTask == nil {
            scheduleFlush()
        }
    }

    private func scheduleFlush() {
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.flushIntervalNanoseconds ?? 250_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.flushBuffer()
        }
    }

    private func flushBuffer() {
        flushTask = nil
        guard !buffer.isEmpty else { return }

        let currentBatch = buffer
        buffer.removeAll(keepingCapacity: true)

        // Group by serviceID to batch file appends
        var grouped: [UUID: [QueuedLog]] = [:]
        for item in currentBatch {
            grouped[item.serviceID, default: []].append(item)
        }

        let dateFormatter = ISO8601DateFormatter()

        for (serviceID, items) in grouped {
            let serviceDir = logsDirectory.appendingPathComponent(serviceID.uuidString, isDirectory: true)
            try? FileManager.default.createDirectory(at: serviceDir, withIntermediateDirectories: true)

            // 1 file per day / session rotation
            let dayString = dateFormatter.string(from: Date()).prefix(10) // YYYY-MM-DD
            let fileURL = serviceDir.appendingPathComponent("\(dayString).log")

            var payload = ""
            for it in items {
                let time = dateFormatter.string(from: it.timestamp)
                payload += "[\(time)] [\(it.level)] \(it.message)\n"
            }

            guard let data = payload.data(using: .utf8) else { continue }

            if FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) {
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    defer { try? fileHandle.close() }
                    _ = try? fileHandle.seekToEnd()
                    try? fileHandle.write(contentsOf: data)
                }
            } else {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }

    /// Explicitly flushes any pending buffer contents (e.g., on app termination).
    public func flushAll() {
        flushBuffer()
    }
}
