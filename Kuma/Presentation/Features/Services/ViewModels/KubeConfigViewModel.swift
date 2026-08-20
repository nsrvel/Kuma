import Foundation
import Observation
import os

// MARK: - KubeConfigViewModel

@Observable
@MainActor
public final class KubeConfigViewModel {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "KubeConfigViewModel")

    public var availableKubeConfigs: [KubeConfig] = []
    public var selectedKubeConfigID: UUID? = nil {
        didSet {
            if oldValue != selectedKubeConfigID {
                refreshContextsForCurrentConfig()
                triggerBackgroundValidation()
            }
        }
    }

    /// Extracted context names from the currently selected kubeconfig
    public var availableContexts: [String] = []
    /// The active context defined by `current-context:` in the yaml
    public var activeContextName: String? = nil

    // Form inline states
    public var showInlineNewConfigForm: Bool = false
    public var editingKubeConfigID: UUID? = nil
    public var showDeleteConfirmation: Bool = false
    public var newKubeConfigName: String = ""
    public var newKubeConfigContent: String = ""

    // Connection testing states
    public var connectionError: String? = nil
    public var isLoadingNamespaces: Bool = false
    public var connectionSuccess: Bool = false

    private let repo: any KubeConfigRepositoryProtocol
    private var activeValidationTask: Task<Void, Never>? = nil

    public init(repo: any KubeConfigRepositoryProtocol = KubeConfigRepository()) {
        self.repo = repo
        self.loadConfigs()
    }

    public func loadConfigs() {
        Task {
            var list: [KubeConfig] = []

            // 1. Resolve default system Kubeconfig (~/.kube/config or custom setting)
            let customPath = UserDefaults.standard.string(forKey: "kuma.custom_kubeconfig_path")
            if let defaultPath = DependencyChecker.resolvedKubeconfigPath(customPath: customPath) {
                let content = (try? String(contentsOfFile: defaultPath, encoding: .utf8)) ?? ""
                let defaultConfig = KubeConfig(
                    id: KubeConfig.defaultID,
                    name: "Default (~/.kube/config)",
                    configContent: content,
                    isDefault: true
                )
                list.append(defaultConfig)
            }

            // 2. Fetch custom registered configs from DB and decrypt contents
            if let customConfigs = try? await repo.fetchAll() {
                var decryptedList: [KubeConfig] = []
                for config in customConfigs {
                    var decrypted = config
                    if let plain = try? await CryptoVault.shared.decrypt(cipherText: config.configContent) {
                        decrypted.configContent = plain
                    }
                    decryptedList.append(decrypted)
                }
                list.append(contentsOf: decryptedList)
            }

            self.availableKubeConfigs = list
            if selectedKubeConfigID == nil, let first = list.first {
                self.selectedKubeConfigID = first.id
            }
            refreshContextsForCurrentConfig()
            triggerBackgroundValidation()
        }
    }

    /// Extract context names from the currently selected kubeconfig YAML content
    public func refreshContextsForCurrentConfig() {
        guard let configID = selectedKubeConfigID,
              let config = availableKubeConfigs.first(where: { $0.id == configID }) else {
            self.availableContexts = []
            self.activeContextName = nil
            return
        }
        self.activeContextName = Self.parseCurrentContext(fromYaml: config.configContent)
        self.availableContexts = Self.parseContexts(fromYaml: config.configContent)
    }

    /// Parses the `current-context: ...` value from YAML
    public static func parseCurrentContext(fromYaml yaml: String) -> String? {
        let lines = yaml.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "current-context:") {
                let parts = trimmed.components(separatedBy: "current-context:")
                if parts.count >= 2 {
                    let ctx = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
                    return ctx.isEmpty ? nil : ctx
                }
            }
        }
        return nil
    }

    /// High performance line-based parser to extract `- name: ...` under `contexts:` in kubeconfig
    public static func parseContexts(fromYaml yaml: String) -> [String] {
        var contexts: [String] = []
        var inContextsBlock = false

        let lines = yaml.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.starts(with: "contexts:") {
                inContextsBlock = true
                continue
            }
            if inContextsBlock {
                // If we encounter another top-level root key without leading spaces (e.g. "users:", "clusters:"), stop
                if !line.starts(with: " ") && !line.starts(with: "\t") && trimmed.contains(":") && !trimmed.starts(with: "-") {
                    break
                }
                if trimmed.starts(with: "- name:") || (trimmed.starts(with: "name:") && line.starts(with: " ")) {
                    let parts = trimmed.components(separatedBy: "name:")
                    if parts.count >= 2 {
                        let name = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: "")
                        if !name.isEmpty && !contexts.contains(name) {
                            contexts.append(name)
                        }
                    }
                }
            }
        }
        return contexts
    }

    public func saveConfig() async {
        let name = newKubeConfigName.trimmingCharacters(in: .whitespacesAndNewlines)
        let plainContent = newKubeConfigContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty && !plainContent.isEmpty else { return }

        do {
            // Encrypt content using AES-256-GCM MasterKey before writing to database
            let encryptedContent = try await CryptoVault.shared.encrypt(plainText: plainContent)

            if let editID = editingKubeConfigID {
                let updated = KubeConfig(
                    id: editID,
                    name: name,
                    configContent: encryptedContent,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                try await repo.update(updated)
            } else {
                let newID = UUID()
                let newConfig = KubeConfig(
                    id: newID,
                    name: name,
                    configContent: encryptedContent,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                try await repo.insert(newConfig)
                selectedKubeConfigID = newID
            }
            loadConfigs()
            showInlineNewConfigForm = false
            newKubeConfigName = ""
            newKubeConfigContent = ""
            editingKubeConfigID = nil
        } catch {
            Self.logger.error("Failed to encrypt/save KubeConfig: \(error.localizedDescription)")
        }
    }

    public func deleteConfig() async {
        guard let id = selectedKubeConfigID, id != KubeConfig.defaultID else { return }
        try? await repo.delete(id: id)
        selectedKubeConfigID = availableKubeConfigs.first?.id
        loadConfigs()
    }

    // MARK: - Non-blocking Background Validation & Caching

    public func triggerBackgroundValidation(context: String = "", forceRefresh: Bool = false) {
        activeValidationTask?.cancel()

        guard let configID = selectedKubeConfigID,
              let config = availableKubeConfigs.first(where: { $0.id == configID }) else {
            self.connectionError = nil
            self.connectionSuccess = false
            self.isLoadingNamespaces = false
            return
        }

        let content = config.configContent
        self.isLoadingNamespaces = true
        self.connectionError = nil
        self.connectionSuccess = false

        activeValidationTask = Task {
            let result = await KubeConnectionValidator.shared.validateConnection(
                configContent: content,
                context: context,
                forceRefresh: forceRefresh
            )

            guard !Task.isCancelled else { return }

            await MainActor.run {
                self.isLoadingNamespaces = false
                if result.isReachable {
                    self.connectionSuccess = true
                    self.connectionError = nil
                } else {
                    self.connectionSuccess = false
                    self.connectionError = result.errorMessage ?? "Unable to reach cluster"
                }
            }
        }
    }

    public func testConnection(context: String = "") {
        triggerBackgroundValidation(context: context, forceRefresh: true)
    }
}
