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
}
