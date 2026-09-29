import Foundation
import Testing
@testable import Kuma

@Suite("Feature 06: Log console render state")
struct KumaLogConsoleRenderTests {

    @Test("TC-L11: canAppendTail when entry IDs are stable and count grows")
    func testCanAppendTailWithStableIDs() {
        let id1 = UUID()
        let id2 = UUID()
        let entries = [
            LiveLogEntry(id: id1, serviceID: UUID(), serviceName: "", message: "a"),
            LiveLogEntry(id: id2, serviceID: UUID(), serviceName: "", message: "b"),
        ]
        #expect(
            LogConsoleRenderState.canAppendTail(
                entries: entries,
                lastRenderedCount: 1,
                firstEntryID: id1,
                lastEntriesID: id1
            )
        )
        #expect(
            !LogConsoleRenderState.canAppendTail(
                entries: entries,
                lastRenderedCount: 1,
                firstEntryID: UUID(),
                lastEntriesID: id1
            )
        )
    }

    @Test("TC-L12: LiveLogSession coalesces rapid ingest on flush")
    @MainActor
    func testLiveLogSessionCoalescesFlush() {
        let session = LiveLogSession.shared
        session.stop()
        session.clear()
        let serviceID = UUID()
        session.testing_bindActiveService(serviceID)
        session.testing_ingest("one\n")
        session.testing_ingest("two\n")
        session.testing_flushPendingNow()
        #expect(session.lines.count == 2)
        session.stop()
        session.clear()
    }
}
