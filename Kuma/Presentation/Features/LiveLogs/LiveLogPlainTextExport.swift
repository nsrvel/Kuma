import AppKit
import UniformTypeIdentifiers

enum LiveLogPlainTextExport {
    @MainActor
    static func save(defaultFilename: String, text: String) {
        guard !text.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = defaultFilename
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func sanitizedFilename(serviceName: String) -> String {
        let trimmed = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "service" : trimmed
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        var safe = ""
        for scalar in base.unicodeScalars {
            safe += allowed.contains(scalar) ? String(scalar) : "-"
        }
        while safe.contains("--") {
            safe = safe.replacingOccurrences(of: "--", with: "-")
        }
        return "\(safe)-logs.txt"
    }
}
