import Foundation
import GRDB
import os

/// Production-ready Database Engine conforming to pure Swift 6 Concurrency.
/// Uses a thread-safe DatabasePool/DatabaseQueue with WAL mode, foreign keys, and typed migrations.
public nonisolated final class AppDatabase: Sendable {
    private static let logger = Logger(subsystem: "lokastudio.kuma", category: "AppDatabase")

    public static let shared = AppDatabase()

    public let dbWriter: any DatabaseWriter

    public init() {
        do {
            let fileManager = FileManager.default
            let appSupportURL = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let folderURL = appSupportURL.appendingPathComponent("Kuma", isDirectory: true)
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)

            let dbURL = folderURL.appendingPathComponent("kuma.sqlite")

            var config = Configuration()
            config.journalMode = .wal
            config.qos = .userInitiated
            config.prepareDatabase { db in
                try? db.execute(sql: "PRAGMA foreign_keys = ON")
            }

            self.dbWriter = try DatabasePool(path: dbURL.path(percentEncoded: false), configuration: config)
            try migrator.migrate(dbWriter)
            Self.logger.info("Database initialized successfully at \(dbURL.path(percentEncoded: false))")
        } catch {
            fatalError("Failed to initialize SQLite database: \(error)")
        }
    }

    /// In-memory queue for lightning-fast, zero-side-effect automated testing
    public init(inMemory: Bool) {
        guard inMemory else {
            fatalError("Use default init for disk-based database")
        }
        do {
            var config = Configuration()
            config.qos = .userInitiated
            config.prepareDatabase { db in
                try? db.execute(sql: "PRAGMA foreign_keys = ON")
            }
            self.dbWriter = try DatabaseQueue(configuration: config)
            try migrator.migrate(dbWriter)
        } catch {
            fatalError("Failed to initialize in-memory database: \(error)")
        }
    }

    /// Completely wipes all user tables and re-seeds starter workspace
    public func wipeAndResetDatabase() throws {
        try dbWriter.write { db in
            try db.execute(sql: "PRAGMA foreign_keys = OFF")
            let tables = try String.fetchAll(db, sql: "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name != 'grdb_migrations'")
            for table in tables {
                try db.execute(sql: "DELETE FROM \(table)")
            }
            try db.execute(sql: "PRAGMA foreign_keys = ON")

            let defaultWS = Workspace.defaultWorkspace
            try defaultWS.insert(db)
        }
        Self.logger.info("Database wiped and reset to factory defaults")
    }

    // MARK: - Migrator

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        // Speed up development tests
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_production_schema") { db in
            // 1. Workspace Table
            try db.create(table: "workspace") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("imagePath", .text)
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // 1.5 KubeConfig Table
            try db.create(table: "kube_config") { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("configContent", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // 2. Service Table
            try db.create(table: "service") { t in
                t.column("id", .text).primaryKey()
                t.column("workspaceID", .text).notNull().references("workspace", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("icon", .text)
                t.column("colorHex", .text)
                t.column("description", .text)
                t.column("activeProviderID", .text)
                t.column("isDisabled", .boolean).notNull().defaults(to: false)
                t.column("isStarred", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // 3. Provider Table
            try db.create(table: "provider") { t in
                t.column("id", .text).primaryKey()
                t.column("serviceID", .text).notNull().references("service", onDelete: .cascade)
                t.column("type", .text).notNull()
                t.column("label", .text)

                // K8s
                t.column("kubeConfigID", .text)
                t.column("kubeContext", .text)
                t.column("kubeNamespace", .text)
                t.column("targetName", .text)
                t.column("kubeTargetType", .text)
                t.column("usePattern", .boolean)

                // Docker / Podman
                t.column("yamlConfig", .text)
                t.column("initialScript", .text)

                // Shell
                t.column("runCommand", .text)
                t.column("workingDirectory", .text)

                // SSH
                t.column("sshHost", .text)
                t.column("sshUser", .text)
                t.column("sshPort", .integer)
                t.column("sshKeyPath", .text)
                t.column("sshPassword", .text)

                // Health Check & Tunnel
                t.column("httpCheckUrl", .text)
                t.column("httpCheckInterval", .integer)
                t.column("tunnelType", .text)
                t.column("tunnelTargetUrl", .text)
                t.column("ngrokAuthToken", .text)

                // Process Monitor
                t.column("monitorProcessName", .text)
                t.column("monitorInterval", .integer)

                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // 4. Port Mapping Table
            try db.create(table: "portMapping") { t in
                t.column("id", .text).primaryKey()
                t.column("serviceID", .text).notNull().references("service", onDelete: .cascade)
                t.column("localPort", .integer).notNull()
                t.column("remotePort", .integer).notNull()
                t.column("protocolType", .text).notNull().defaults(to: "TCP")
            }

            // Indices for ultra-fast query projection
            try db.create(index: "idx_service_workspace", on: "service", columns: ["workspaceID", "createdAt"])
            try db.create(index: "idx_provider_service", on: "provider", columns: ["serviceID"])
            try db.create(index: "idx_port_service", on: "portMapping", columns: ["serviceID"])

            // Seed Starter Default Workspace
            let defaultWS = Workspace.defaultWorkspace
            try db.execute(
                sql: """
                INSERT INTO workspace (id, name, imagePath, sortOrder, createdAt, updatedAt)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    defaultWS.id.uuidString,
                    defaultWS.name,
                    defaultWS.imagePath,
                    defaultWS.sortOrder,
                    defaultWS.createdAt,
                    defaultWS.updatedAt
                ]
            )
        }

        migrator.registerMigration("v2_service_groups") { db in
            // 1. ServiceGroup Table
            try db.create(table: "service_group") { t in
                t.column("id", .text).primaryKey()
                t.column("workspaceID", .text).notNull().references("workspace", onDelete: .cascade)
                t.column("name", .text).notNull()
                t.column("sortOrder", .integer).notNull().defaults(to: 0)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }

            // 2. Add groupID column to service table (onDelete setNull keeps service alive if group deleted)
            try db.alter(table: "service") { t in
                t.add(column: "groupID", .text).references("service_group", onDelete: .setNull)
            }

            // 3. Index for fast workspace-scoped group queries
            try db.create(index: "idx_group_workspace", on: "service_group", columns: ["workspaceID", "sortOrder"])
        }

        migrator.registerMigration("v3_service_group_memberships") { db in
            // 1. Join table for Many-to-Many service <-> group relationship
            try db.create(table: "service_group_membership") { t in
                t.column("serviceID", .text).notNull().references("service", onDelete: .cascade)
                t.column("groupID", .text).notNull().references("service_group", onDelete: .cascade)
                t.column("createdAt", .datetime).notNull()
                t.primaryKey(["serviceID", "groupID"])
            }

            // 2. Migrate existing single groupID to join table
            try db.execute(sql: """
                INSERT OR IGNORE INTO service_group_membership (serviceID, groupID, createdAt)
                SELECT id, groupID, datetime('now')
                FROM service
                WHERE groupID IS NOT NULL AND groupID != ''
            """)

            // 3. Performance index on groupID lookup
            try db.create(index: "idx_membership_group", on: "service_group_membership", columns: ["groupID", "serviceID"])
        }

        return migrator
    }
}
