import Foundation
import GRDB

// MARK: - Workspace GRDB Record Conformance

extension Workspace: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "workspace"

    public nonisolated init(row: Row) throws {
        let idStr: String = row["id"]
        let id = UUID(uuidString: idStr) ?? UUID()
        let name: String = row["name"]
        let imagePath: String? = row["imagePath"]
        let sortOrder: Int = row["sortOrder"]
        let createdAt: Date = row["createdAt"]
        let updatedAt: Date = row["updatedAt"]

        self.init(
            id: id,
            name: name,
            imagePath: imagePath,
            sortOrder: sortOrder,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public nonisolated func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id.uuidString
        container["name"] = name
        container["imagePath"] = imagePath
        container["sortOrder"] = sortOrder
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
    }
}

// MARK: - Service GRDB Record Conformance

extension Service: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "service"

    public nonisolated init(row: Row) throws {
        let idStr: String = row["id"]
        let id = UUID(uuidString: idStr) ?? UUID()
        let wsStr: String? = row["workspaceID"]
        let workspaceID = wsStr.flatMap(UUID.init)
        let name: String = row["name"]
        let icon: String? = row["icon"]
        let colorHex: String? = row["colorHex"]
        let description: String? = row["description"]
        let activeProvStr: String? = row["activeProviderID"]
        let activeProviderID = activeProvStr.flatMap(UUID.init)
        let isDisabled: Bool = row["isDisabled"]
        let createdAt: Date = row["createdAt"]
        let updatedAt: Date = row["updatedAt"]

        self.init(
            id: id,
            name: name,
            icon: icon,
            colorHex: colorHex,
            description: description,
            activeProviderID: activeProviderID,
            workspaceID: workspaceID,
            isDisabled: isDisabled,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public nonisolated func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id.uuidString
        container["workspaceID"] = workspaceID?.uuidString
        container["name"] = name
        container["icon"] = icon
        container["colorHex"] = colorHex
        container["description"] = description
        container["activeProviderID"] = activeProviderID?.uuidString
        container["isDisabled"] = isDisabled
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
    }
}

// MARK: - Provider GRDB Record Conformance

extension Provider: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "provider"

    public nonisolated init(row: Row) throws {
        let idStr: String = row["id"]
        let id = UUID(uuidString: idStr) ?? UUID()
        let serviceStr: String = row["serviceID"]
        let serviceID = UUID(uuidString: serviceStr) ?? UUID()
        let typeRaw: String = row["type"]
        let type = ProviderCategory(rawValue: typeRaw) ?? .docker
        let label: String? = row["label"]

        let kubeConfigStr: String? = row["kubeConfigID"]
        let kubeConfigID = kubeConfigStr.flatMap(UUID.init)
        let kubeContext: String? = row["kubeContext"]
        let kubeNamespace: String? = row["kubeNamespace"]
        let targetName: String? = row["targetName"]
        let kubeTargetType: String? = row["kubeTargetType"]
        let usePattern: Bool? = row["usePattern"]

        let yamlConfig: String? = row["yamlConfig"]
        let initialScript: String? = row["initialScript"]

        let runCommand: String? = row["runCommand"]
        let workingDirectory: String? = row["workingDirectory"]

        let sshHost: String? = row["sshHost"]
        let sshUser: String? = row["sshUser"]
        let sshPort: Int? = row["sshPort"]
        let sshKeyPath: String? = row["sshKeyPath"]
        let sshPassword: String? = row["sshPassword"]

        let httpCheckUrl: String? = row["httpCheckUrl"]
        let httpCheckInterval: Int? = row["httpCheckInterval"]
        let tunnelType: String? = row["tunnelType"]
        let tunnelTargetUrl: String? = row["tunnelTargetUrl"]
        let ngrokAuthToken: String? = row["ngrokAuthToken"]

        let monitorProcessName: String? = row["monitorProcessName"]
        let monitorInterval: Int? = row["monitorInterval"]

        let createdAt: Date = row["createdAt"]
        let updatedAt: Date = row["updatedAt"]

        self.init(
            id: id,
            serviceID: serviceID,
            type: type,
            label: label,
            kubeConfigID: kubeConfigID,
            kubeContext: kubeContext,
            kubeNamespace: kubeNamespace,
            targetName: targetName,
            kubeTargetType: kubeTargetType,
            usePattern: usePattern,
            yamlConfig: yamlConfig,
            initialScript: initialScript,
            runCommand: runCommand,
            workingDirectory: workingDirectory,
            sshHost: sshHost,
            sshUser: sshUser,
            sshPort: sshPort,
            sshKeyPath: sshKeyPath,
            sshPassword: sshPassword,
            httpCheckUrl: httpCheckUrl,
            httpCheckInterval: httpCheckInterval,
            tunnelType: tunnelType,
            tunnelTargetUrl: tunnelTargetUrl,
            ngrokAuthToken: ngrokAuthToken,
            monitorProcessName: monitorProcessName,
            monitorInterval: monitorInterval,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    public nonisolated func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id.uuidString
        container["serviceID"] = serviceID.uuidString
        container["type"] = type.rawValue
        container["label"] = label
        container["kubeConfigID"] = kubeConfigID?.uuidString
        container["kubeContext"] = kubeContext
        container["kubeNamespace"] = kubeNamespace
        container["targetName"] = targetName
        container["kubeTargetType"] = kubeTargetType
        container["usePattern"] = usePattern
        container["yamlConfig"] = yamlConfig
        container["initialScript"] = initialScript
        container["runCommand"] = runCommand
        container["workingDirectory"] = workingDirectory
        container["sshHost"] = sshHost
        container["sshUser"] = sshUser
        container["sshPort"] = sshPort
        container["sshKeyPath"] = sshKeyPath
        container["sshPassword"] = sshPassword
        container["httpCheckUrl"] = httpCheckUrl
        container["httpCheckInterval"] = httpCheckInterval
        container["tunnelType"] = tunnelType
        container["tunnelTargetUrl"] = tunnelTargetUrl
        container["ngrokAuthToken"] = ngrokAuthToken
        container["monitorProcessName"] = monitorProcessName
        container["monitorInterval"] = monitorInterval
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
    }
}

// MARK: - ServicePortMapping GRDB Record Conformance

extension ServicePortMapping: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "portMapping"

    public nonisolated init(row: Row) throws {
        let idStr: String = row["id"]
        let id = UUID(uuidString: idStr) ?? UUID()
        let localPort: Int = row["localPort"]
        let remotePort: Int = row["remotePort"]
        let protocolType: String = row["protocolType"]

        self.init(
            id: id,
            localPort: localPort,
            remotePort: remotePort,
            protocolType: protocolType
        )
    }

    public nonisolated func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id.uuidString
        container["localPort"] = localPort
        container["remotePort"] = remotePort
        container["protocolType"] = protocolType
    }
}
