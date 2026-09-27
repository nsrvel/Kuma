import Foundation

/// PROC-04: Avoid blocking Swift Concurrency cooperative threads on `Process.waitUntilExit()`.
enum SubprocessWait {
    static func waitForExit(of process: Process) async {
        await Task.detached(priority: .utility) {
            process.waitUntilExit()
        }.value
    }
}
