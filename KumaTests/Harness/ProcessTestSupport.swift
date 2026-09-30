import Foundation
@testable import Kuma

/// Resets global process/supervisor state between serialized integration tests.
enum ProcessTestSupport {
    static func resetProcessWorld() async {
        await ExecutionSupervisor.shared.stopAll()
        await ProcessRegistry.shared.terminateAllAsync()
    }
}
