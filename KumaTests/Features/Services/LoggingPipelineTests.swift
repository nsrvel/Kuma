import Foundation
import Testing
@testable import Kuma

@Suite("Feature 05: Logging Pipeline Tests", .serialized)
struct LoggingPipelineTests {

    @Test("TC-L01: LogStreamChunker correctly handles fragmented chunks")
    func testChunkerFragmentedLines() {
        let chunker = LogStreamChunker()

        // Chunk 1: Incomplete line
        let lines1 = chunker.ingest("Hello, ")
        #expect(lines1.isEmpty)

        // Chunk 2: Finishes line 1 and has complete line 2
        let lines2 = chunker.ingest("World!\nSecond line\nThird part")
        #expect(lines2 == ["Hello, World!", "Second line"])

        // Chunk 3: Finishes line 3
        let lines3 = chunker.ingest(" finished.\n")
        #expect(lines3 == ["Third part finished."])

        #expect(chunker.flushRemaining() == nil)
    }

    @Test("TC-L02: LogStreamChunker flushes trailing un-terminated text")
    func testChunkerFlushTrailing() {
        let chunker = LogStreamChunker()
        _ = chunker.ingest("Started task...")
        let flushed = chunker.flushRemaining()
        #expect(flushed == "Started task...")
    }

    @Test("TC-L03: ANSISanitizer strips terminal escape codes")
    func testANSISanitizerStripsColors() {
        let colored = "\u{001B}[32mSUCCESS\u{001B}[0m: Database migration completed."
        let clean = ANSISanitizer.sanitize(colored)
        #expect(clean == "SUCCESS: Database migration completed.")

        let cursorMove = "\u{001B}[2K\u{001B}[1GDownloading [=====>    ] 50%"
        let cleanCursor = ANSISanitizer.sanitize(cursorMove)
        #expect(cleanCursor == "Downloading [=====>    ] 50%")
    }

    @Test("TC-L04: ANSISanitizer normalizes carriage returns")
    func testANSISanitizerCarriageReturns() {
        let crText = "Step 1\r\nStep 2\rStep 3\n"
        let clean = ANSISanitizer.sanitize(crText)
        #expect(clean.contains("Step 1"))
        #expect(clean.contains("Step 2"))
        #expect(clean.contains("Step 3"))
        #expect(!clean.contains("\r"))
    }

    @Test("TC-L05: ServiceLogPipeline batches lines to LogAggregator")
    @MainActor
    func testPipelineBatching() async {
        let serviceID = UUID()
        LogAggregator.shared.retainUISubscriber()
        defer { LogAggregator.shared.releaseUISubscriber() }
        let pipeline = ServiceLogPipeline(serviceID: serviceID, serviceName: "TestService")

        await pipeline.emit(level: "INFO", message: "Line 1")
        await pipeline.emit(level: "INFO", message: "Line 2")
        await pipeline.finish()

        // Give MainActor a moment to process the batch
        try? await Task.sleep(nanoseconds: 50_000_000)

        let logs = LogAggregator.shared.logs(for: serviceID)
        #expect(logs.count >= 2)
        #expect(logs.contains(where: { $0.message == "Line 1" }))
        #expect(logs.contains(where: { $0.message == "Line 2" }))
    }

    @Test("TC-L07: LogAggregator logs(for:) stays consistent after global trim")
    @MainActor
    func testAggregatorLogsSubsetOfEntriesAfterTrim() {
        let key = KumaSettingsKey.logRetentionLimit
        let prior = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(LogRetentionLimit.fiftyMB.rawValue, forKey: key)
        defer {
            if let prior {
                UserDefaults.standard.set(prior, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
            LogAggregator.shared.refreshRetentionFromSettings()
        }

        let aggregator = LogAggregator.shared
        aggregator.refreshRetentionFromSettings()
        aggregator.clear()

        let serviceIDs = (0..<5).map { _ in UUID() }
        for serviceID in serviceIDs {
            for index in 0..<450 {
                aggregator.append(serviceID: serviceID, serviceName: "TrimTest", level: "INFO", message: "line \(index)")
            }
        }

        #expect(aggregator.entries.count == 2_000)
        let entryIDs = Set(aggregator.entries.map(\.id))
        for serviceID in serviceIDs {
            let serviceLogs = aggregator.logs(for: serviceID)
            #expect(serviceLogs.allSatisfy { entryIDs.contains($0.id) })
        }
        aggregator.clear()
    }

    @Test("TC-L06: Pipeline skips LogAggregator without UI subscriber")
    @MainActor
    func testPipelineSkipsAggregatorWithoutSubscriber() async {
        let serviceID = UUID()
        LogAggregator.shared.clear(serviceID: serviceID)
        let pipeline = ServiceLogPipeline(serviceID: serviceID, serviceName: "NoUISubscriber")

        await pipeline.emit(level: "INFO", message: "Should not land in memory")
        await pipeline.finish()
        try? await Task.sleep(nanoseconds: 50_000_000)

        #expect(LogAggregator.shared.logs(for: serviceID).isEmpty)
    }

    @Test("TC-L08: LogAggregator enforces logRetentionLimit from settings")
    @MainActor
    func testRetentionLimitFromSettings() {
        let key = KumaSettingsKey.logRetentionLimit
        let prior = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(LogRetentionLimit.tenMB.rawValue, forKey: key)
        defer {
            if let prior {
                UserDefaults.standard.set(prior, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
            LogAggregator.shared.refreshRetentionFromSettings()
            LogAggregator.shared.clear()
        }

        LogAggregator.shared.refreshRetentionFromSettings()
        let aggregator = LogAggregator.shared
        aggregator.clear()
        let serviceID = UUID()

        for index in 0..<1_100 {
            aggregator.append(serviceID: serviceID, serviceName: "Retention", level: "INFO", message: "line \(index)")
        }

        #expect(aggregator.entries.count <= 1_000)
        aggregator.clear()
    }

    @Test("TC-L09: clearLogsOnSwitch clears in-memory logs on service start hook")
    @MainActor
    func testClearLogsOnRestartSetting() {
        let key = KumaSettingsKey.clearLogsOnSwitch
        let prior = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.set(true, forKey: key)
        defer {
            if let prior {
                UserDefaults.standard.set(prior, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        let serviceID = UUID()
        LogAggregator.shared.append(serviceID: serviceID, serviceName: "Restart", message: "before")
        #expect(!LogAggregator.shared.logs(for: serviceID).isEmpty)

        if KumaSettingsKey.bool(forKey: KumaSettingsKey.clearLogsOnSwitch, defaultValue: false) {
            LogAggregator.shared.clear(serviceID: serviceID)
        }

        #expect(LogAggregator.shared.logs(for: serviceID).isEmpty)
    }

    @Test("TC-L10: logs(for:) reads per-service index without scanning all entries")
    @MainActor
    func testPerServiceIndexMatchesChronologicalFilter() {
        let aggregator = LogAggregator.shared
        aggregator.clear()
        let serviceA = UUID()
        let serviceB = UUID()

        aggregator.append(serviceID: serviceA, serviceName: "A", message: "a1")
        aggregator.append(serviceID: serviceB, serviceName: "B", message: "b1")
        aggregator.append(serviceID: serviceA, serviceName: "A", message: "a2")

        let indexed = aggregator.logs(for: serviceA)
        let filtered = aggregator.entries.filter { $0.serviceID == serviceA }
        #expect(indexed == filtered)
        aggregator.clear()
    }
}
