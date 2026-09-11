import AppKit
import Testing
@testable import Kuma

// MARK: - Mock Performer

@MainActor
private final class MockHapticPerformer: NSObject, NSHapticFeedbackPerformer {
    var performedPatterns: [NSHapticFeedbackManager.FeedbackPattern] = []

    func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern, performanceTime: NSHapticFeedbackManager.PerformanceTime) {
        performedPatterns.append(pattern)
    }
}

// MARK: - KumaHapticManagerTests

@Suite("Feature 00 - Category G: Native Trackpad Haptic Feedback Manager")
@MainActor
struct KumaHapticManagerTests {

    @Test("TC-G01: KumaHapticManager fires generic pattern on tap()")
    func testHapticTap() {
        let mock = MockHapticPerformer()
        let manager = KumaHapticManager(performer: mock)
        manager.tap()
        #expect(mock.performedPatterns == [.generic])
    }

    @Test("TC-G02: KumaHapticManager fires alignment pattern on alignment()")
    func testHapticAlignment() {
        let mock = MockHapticPerformer()
        let manager = KumaHapticManager(performer: mock)
        manager.alignment()
        #expect(mock.performedPatterns == [.alignment])
    }

    @Test("TC-G03: KumaHapticManager fires levelChange pattern on levelChange()")
    func testHapticLevelChange() {
        let mock = MockHapticPerformer()
        let manager = KumaHapticManager(performer: mock)
        manager.levelChange()
        #expect(mock.performedPatterns == [.levelChange])
    }

    @Test("TC-G04: Shared instance executes without throwing")
    func testSharedInstanceSafeExecution() {
        KumaHapticManager.shared.tap()
        KumaHapticManager.shared.alignment()
        KumaHapticManager.shared.levelChange()
        #expect(true)
    }
}
