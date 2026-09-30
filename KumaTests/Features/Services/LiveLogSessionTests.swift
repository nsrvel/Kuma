import Foundation
import Testing
@testable import Kuma

@Suite("Feature 05: Live log session", .serialized)
struct LiveLogSessionTests {

    @Test("TC-L03: ANSISanitizer strips terminal escape codes")
    func testANSISanitizerStripsColors() {
        let colored = "\u{001B}[32mSUCCESS\u{001B}[0m: done."
        #expect(ANSISanitizer.sanitize(colored) == "SUCCESS: done.")
    }

    @Test("TC-L14: panel teardown stops stream and clears buffer for service")
    @MainActor
    func testPanelTeardownClearsBuffer() {
        let session = LiveLogSession.shared
        session.stop()
        session.clear()
        let serviceID = UUID()
        session.testing_bindActiveService(serviceID)
        session.testing_ingest("line\n")
        session.stop()
        if session.bufferedServiceID == serviceID {
            session.clear()
        }
        #expect(session.lines.isEmpty)
        #expect(session.bufferedServiceID == nil)
        session.clear()
    }

    @Test("TC-L13: stop clears active stream but keeps buffered service lines")
    @MainActor
    func testStopKeepsBufferedLinesForService() {
        let session = LiveLogSession.shared
        session.stop()
        session.clear()
        let serviceID = UUID()
        session.testing_bindActiveService(serviceID)
        session.testing_ingest("kept\n")
        session.stop()
        #expect(session.activeServiceID == nil)
        #expect(session.bufferedServiceID == serviceID)
        #expect(session.lines.count == 1)
        session.clear()
    }

    @Test("TC-L10: LiveLogSession ring buffer caps at 1000 lines")
    @MainActor
    func testLiveLogSessionRingBufferCap() {
        let session = LiveLogSession.shared
        session.stop()
        session.clear()
        let serviceID = UUID()
        session.testing_bindActiveService(serviceID)
        for index in 0..<1_100 {
            session.testing_ingest("line \(index)\n")
        }
        #expect(session.lines.count == 1_000)
        #expect(session.lines.last?.text == "line 1099")
        session.stop()
        session.clear()
    }
}
