import Foundation

public struct Provider: Identifiable, Codable, Sendable, Equatable, Hashable {
    public var id: UUID
    public var serviceID: UUID
    public var type: ProviderCategory
    public var label: String?

    // Kubernetes Port Forward
    public var kubeConfigID: UUID?
    public var kubeContext: String?
    public var kubeNamespace: String?
    public var targetName: String?
    public var kubeTargetType: String?
    public var usePattern: Bool?

    // Docker & Podman Compose
    public var yamlConfig: String?
    public var initialScript: String?

    // Shell Execution
    public var runCommand: String?
    public var workingDirectory: String?

    // SSH Remote
    public var sshHost: String?
    public var sshUser: String?
    public var sshPort: Int?
    public var sshKeyPath: String?
    public var sshPassword: String?

    // Health Check & Public Tunnel
    public var httpCheckUrl: String?
    public var httpCheckInterval: Int?
    public var tunnelType: String?
    public var tunnelTargetUrl: String?
    public var ngrokAuthToken: String?

    // Process Monitor
    public var monitorProcessName: String?
    public var monitorInterval: Int?

    public var createdAt: Date
    public var updatedAt: Date

    public nonisolated init(
        id: UUID = UUID(),
        serviceID: UUID,
        type: ProviderCategory,
        label: String? = nil,
        kubeConfigID: UUID? = nil,
        kubeContext: String? = nil,
        kubeNamespace: String? = nil,
        targetName: String? = nil,
        kubeTargetType: String? = nil,
        usePattern: Bool? = nil,
        yamlConfig: String? = nil,
        initialScript: String? = nil,
        runCommand: String? = nil,
        workingDirectory: String? = nil,
        sshHost: String? = nil,
        sshUser: String? = nil,
        sshPort: Int? = nil,
        sshKeyPath: String? = nil,
        sshPassword: String? = nil,
        httpCheckUrl: String? = nil,
        httpCheckInterval: Int? = nil,
        tunnelType: String? = nil,
        tunnelTargetUrl: String? = nil,
        ngrokAuthToken: String? = nil,
        monitorProcessName: String? = nil,
        monitorInterval: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.serviceID = serviceID
        self.type = type
        self.label = label
        self.kubeConfigID = kubeConfigID
        self.kubeContext = kubeContext
        self.kubeNamespace = kubeNamespace
        self.targetName = targetName
        self.kubeTargetType = kubeTargetType
        self.usePattern = usePattern
        self.yamlConfig = yamlConfig
        self.initialScript = initialScript
        self.runCommand = runCommand
        self.workingDirectory = workingDirectory
        self.sshHost = sshHost
        self.sshUser = sshUser
        self.sshPort = sshPort
        self.sshKeyPath = sshKeyPath
        self.sshPassword = sshPassword
        self.httpCheckUrl = httpCheckUrl
        self.httpCheckInterval = httpCheckInterval
        self.tunnelType = tunnelType
        self.tunnelTargetUrl = tunnelTargetUrl
        self.ngrokAuthToken = ngrokAuthToken
        self.monitorProcessName = monitorProcessName
        self.monitorInterval = monitorInterval
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public nonisolated var displayName: String {
        if let label, !label.trimmingCharacters(in: .whitespaces).isEmpty {
            return label
        }
        return type.sidebarLabel
    }
}
