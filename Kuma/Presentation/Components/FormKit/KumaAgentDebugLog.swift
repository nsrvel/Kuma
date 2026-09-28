import Foundation

// #region agent log
enum KumaAgentDebugLog {
    private nonisolated static let workspaceLogPath =
        "/Users/putra/Development/Personal/Projects/Kuma/Repositories/Kuma/.cursor/debug-a93c31.log"

    private nonisolated static let runtimeLogPath: String = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("debug-a93c31.log").path
    }()

    nonisolated static func write(hypothesisId: String, location: String, message: String, data: [String: String]) {
        let ts = Int(Date().timeIntervalSince1970 * 1000)
        let dataJSON = data.map { "\"\($0.key)\":\"\($0.value.replacingOccurrences(of: "\"", with: "'"))\"" }
            .joined(separator: ",")
        let line =
            "{\"sessionId\":\"a93c31\",\"hypothesisId\":\"\(hypothesisId)\",\"location\":\"\(location)\",\"message\":\"\(message)\",\"data\":{\(dataJSON)},\"timestamp\":\(ts)}\n"
        appendLine(line, to: URL(fileURLWithPath: workspaceLogPath))
        appendLine(line, to: URL(fileURLWithPath: runtimeLogPath))
    }

    private nonisolated static func appendLine(_ line: String, to url: URL) {
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}
// #endregion
