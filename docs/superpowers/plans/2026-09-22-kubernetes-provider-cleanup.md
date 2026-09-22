# Kubernetes Provider Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Kubernetes provider production-complete: correct port-forward for all target types, reliable backup/restore of custom kubeconfigs, aligned create/inspector UX, and tightened validation—without scope-creeping into other providers.

**Architecture:** Keep existing split (`KubeConfigMaterializer` + `KubeConfigExecutionResolver` at run time; `KubeConfigViewModel` in UI; `DataPortRepository` for backup). Extend `ExportKubeConfig` with vault-encrypted YAML (same ciphertext as SQLite). Centralize kube form side-effects in small shared helpers rather than new frameworks. Optional target preflight lives in `KubeConnectionValidator` or a thin `KubeTargetPreflight` used only by runner start (fail fast with clear log).

**Tech Stack:** Swift 5, SwiftUI, GRDB, `CryptoVault`, `kubectl` subprocess, XCTest/`swift-testing` (`@Test`), `xcodebuild test -scheme Kuma`.

## Global Constraints

- macOS deployment target **14.0** (`MACOSX_DEPLOYMENT_TARGET` in `Kuma.xcodeproj`).
- No new third-party dependencies.
- Secrets in SQLite and JSON backups: use **`CryptoVault.shared.encrypt`** for export payloads (mirror `DataPortRepository.toExportProvider` SSH handling).
- Backup schema stays **`DataPortService.currentVersion = 1`**; new JSON fields must be **optional** for backward-compatible decode.
- Follow ponytail: smallest diff, reuse existing repos/parsers; one focused test per non-trivial behavior.
- Do **not** commit unless the user asks.

---

## File map (expected touch list)

| Area | Files |
|------|--------|
| Runtime (already local) | `KubernetesRunner.swift`, `KubeTargetNameMatcher.swift`, `KubeTargetType.swift` |
| DataPort | `DataPortService.swift`, `DataPortRepository.swift`, `DataPortPersistenceAndSyncTests.swift`, `DataPortTestHarness.swift` |
| Create flow | `CreateServiceContextualFormView.swift`, `CreateServicePayloadBuilder.swift`, `CreateServiceSheet.swift` |
| Inspector UX | `InspectorKubernetesFormSection.swift`, optionally `KubeConnectionSettingsView.swift` |
| Validation | `KubeConnectionValidator.swift` (optional preflight) |
| Legacy cleanup | `KubeConfigMaterializer.swift`, `KubeTargetType.swift`, `docs/specs/06-services.md` |
| Service tests | `ServicesValidationAndSecurityTests.swift` |

---

### Task 0: Land in-flight runtime fix (service/deployment + pattern)

**Files:**
- Modify: `Kuma/Core/Execution/Runners/KubernetesRunner.swift`
- Create: `Kuma/Core/Kubernetes/KubeTargetNameMatcher.swift`
- Modify: `Kuma/Domain/Enums/KubeTargetType.swift`
- Test: `KumaTests/Features/Services/ServicesValidationAndSecurityTests.swift` (TC-B04b, TC-B04c)

**Interfaces:**
- Produces: `KubeTargetNameMatcher.matches(pattern:candidate:)`, `KubeTargetType.listResource`, `listNameJSONPath`, `portForwardKind`

- [ ] **Step 1: Run targeted tests**

Run:
```bash
cd /Users/putra/Development/Personal/Projects/Kuma/Repositories/Kuma
xcodebuild test -scheme Kuma -destination 'platform=macOS' \
  -only-testing:KumaTests/ServicesValidationAndSecurityTests/testKubeTargetNameMatcherServicePattern \
  -only-testing:KumaTests/ServicesValidationAndSecurityTests/testKubeTargetNameMatcherDeploymentPattern \
  2>&1 | tail -30
```
Expected: **TEST SUCCEEDED**

- [ ] **Step 2: Commit (when user requests)**

Message suggestion: `fix(k8s): port-forward discovery for service and deployment targets`

---

### Task 1: Extend backup model for kube configs

**Files:**
- Modify: `Kuma/Core/DataPort/DataPortService.swift`
- Test: `KumaTests/Features/DataPort/DataPortValidationAndSecurityTests.swift`

**Interfaces:**
- Produces: `ExportKubeConfig` with `encryptedConfigContent: String?`, `createdAt: Date?`, `updatedAt: Date?`
- Produces: `SingleServiceExport.kubeConfigs: [ExportKubeConfig]` default `[]`

- [ ] **Step 1: Write failing decode/encode test**

Add to `DataPortValidationAndSecurityTests.swift`:

```swift
@Test("TC-B07: ExportKubeConfig round-trips encrypted content field")
func testExportKubeConfigEncryptedFieldRoundTrip() throws {
    let kube = DataPortService.ExportKubeConfig(
        id: UUID(),
        name: "staging",
        path: nil,
        encryptedConfigContent: "vault:cipher:example",
        createdAt: Date(timeIntervalSince1970: 1_700_000_000),
        updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
    )
    let backup = DataPortService.KumaBackup(
        services: [],
        providers: [],
        portMappings: [],
        kubeConfigs: [kube]
    )
    let data = try DataPortService.encodeBackup(backup)
    let decoded = try DataPortService.decodeBackup(from: data)
    #expect(decoded.kubeConfigs.count == 1)
    #expect(decoded.kubeConfigs[0].encryptedConfigContent == "vault:cipher:example")
}
```

- [ ] **Step 2: Run test — expect FAIL** (missing initializer properties)

- [ ] **Step 3: Implement `ExportKubeConfig` fields**

In `DataPortService.swift`, extend `ExportKubeConfig`:

```swift
public struct ExportKubeConfig: Codable, Sendable, Identifiable {
    public let id: UUID
    public let name: String?
    public let path: String? // legacy / default path hint only
    public let encryptedConfigContent: String?
    public let createdAt: Date?
    public let updatedAt: Date?

    public nonisolated init(
        id: UUID = UUID(),
        name: String? = nil,
        path: String? = nil,
        encryptedConfigContent: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) { /* assign all */ }
}
```

Add to `SingleServiceExport`:

```swift
public let kubeConfigs: [ExportKubeConfig]
// init(..., kubeConfigs: [ExportKubeConfig] = [])
```

Update `wrapSingleService` to pass `singleExport.kubeConfigs`.

- [ ] **Step 4: Re-run TC-B07 — PASS**

- [ ] **Step 5: Commit** (on user request): `feat(dataport): extend ExportKubeConfig for encrypted YAML`

---

### Task 2: Export kube_config rows referenced by providers

**Files:**
- Modify: `Kuma/Core/Database/Repositories/DataPortRepository.swift`
- Test: `KumaTests/Features/DataPort/DataPortPersistenceAndSyncTests.swift`

**Interfaces:**
- Consumes: `ExportKubeConfig` from Task 1
- Produces: `DataPortRepository.collectReferencedKubeConfigIDs(providers:) -> Set<UUID>`
- Produces: `DataPortRepository.exportKubeConfigs(ids:) async throws -> [ExportKubeConfig]`

- [ ] **Step 1: Write failing integration test**

In `DataPortPersistenceAndSyncTests.swift` (use `DataPortTestHarness`):

```swift
@Test("TC-C20: Scoped export includes encrypted kube_config rows")
func testExportIncludesReferencedKubeConfigs() async throws {
    let harness = DataPortTestHarness()
    let cipher = try CryptoVault.shared.encrypt(plainText: "apiVersion: v1\nkind: Config\n")
    let kubeID = UUID()
    try await harness.databaseQueue.write { db in
        try db.execute(
            sql: """
            INSERT INTO kube_config (id, name, configContent, createdAt, updatedAt)
            VALUES (?, ?, ?, ?, ?)
            """,
            arguments: [kubeID.uuidString, "Remote", cipher, Date(), Date()]
        )
    }
    let (service, provider) = try await harness.seedKubernetesService(kubeConfigID: kubeID)
    let backup = try await harness.repository.exportData(scope: .service(service.id))
    #expect(backup.kubeConfigs.contains(where: { $0.id == kubeID }))
    #expect(backup.kubeConfigs.first(where: { $0.id == kubeID })?.encryptedConfigContent == cipher)
    #expect(backup.kubeConfigs.first(where: { $0.id == kubeID })?.encryptedConfigContent != "apiVersion:")
}
```

Add `seedKubernetesService` to harness if missing (minimal: service + k8s provider with `kubeConfigID`).

- [ ] **Step 2: Run test — FAIL**

- [ ] **Step 3: Implement export helpers**

```swift
private static func collectReferencedKubeConfigIDs(from providers: [DataPortService.ExportProvider]) -> Set<UUID> {
    Set(providers.compactMap(\.kubeConfigID).filter { $0 != KubeConfig.defaultID })
}

private func exportKubeConfigs(ids: Set<UUID>) async throws -> [DataPortService.ExportKubeConfig] {
    guard !ids.isEmpty else { return [] }
    return try await dbWriter.read { db in
        try ids.compactMap { id -> DataPortService.ExportKubeConfig? in
            guard let row = try KubeConfig.fetchOne(db, key: id.uuidString) else { return nil }
            return DataPortService.ExportKubeConfig(
                id: row.id,
                name: row.name,
                path: nil,
                encryptedConfigContent: row.configContent,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt
            )
        }
    }
}
```

Wire into `exportAll`, `exportWorkspace`, `exportSingleServiceBackup`:
1. Build `exportProviders` as today.
2. `let kubeIDs = Self.collectReferencedKubeConfigIDs(from: exportProviders)`
3. `let kubeConfigs = try await exportKubeConfigs(ids: kubeIDs)`
4. Pass `kubeConfigs:` into `KumaBackup(...)` instead of `[]`.

- [ ] **Step 4: Fix `importSelective` / `importIntoWorkspace` filtered backup** — pass through `backup.kubeConfigs` (filtered: only IDs still referenced by filtered providers).

- [ ] **Step 5: Run TC-C20 + full DataPort suite**

```bash
xcodebuild test -scheme Kuma -destination 'platform=macOS' \
  -only-testing:KumaTests/DataPortPersistenceAndSyncTests 2>&1 | tail -40
```

- [ ] **Step 6: Commit:** `feat(dataport): export referenced kube_config entries`

---

### Task 3: Import kube_config before providers

**Files:**
- Modify: `Kuma/Core/Database/Repositories/DataPortRepository.swift`
- Test: `DataPortPersistenceAndSyncTests.swift`

- [ ] **Step 1: Write failing round-trip test**

```swift
@Test("TC-C21: Import restores kube_config so provider kubeConfigID resolves")
func testImportRestoresKubeConfigs() async throws {
    let harnessA = DataPortTestHarness()
    // seed kube + k8s service, export service scope
    let backup = try await harnessA.repository.exportData(scope: .service(service.id))
    let harnessB = DataPortTestHarness()
    try await harnessB.repository.importData(backup: backup, strategy: .preserveOrMerge)
    let row = try await harnessB.databaseQueue.read { db in
        try KubeConfig.fetchOne(db, key: kubeID.uuidString)
    }
    #expect(row != nil)
    #expect(row?.name == "Remote")
}
```

- [ ] **Step 2: Implement import loop** at start of `importAll` transaction (before providers):

```swift
for exportKube in backup.kubeConfigs {
    guard exportKube.id != KubeConfig.defaultID else { continue }
    guard let cipher = exportKube.encryptedConfigContent, !cipher.isEmpty else { continue }
    let record = KubeConfig(
        id: exportKube.id,
        name: exportKube.name ?? "Imported",
        configContent: cipher,
        createdAt: exportKube.createdAt ?? Date(),
        updatedAt: exportKube.updatedAt ?? Date()
    )
    try record.save(db) // ON CONFLICT via PersistableRecord upsert if configured; else insert or replace
}
```

If GRDB `save` does not upsert, use `INSERT ... ON CONFLICT(id) DO UPDATE SET name=..., configContent=..., updatedAt=...`.

- [ ] **Step 3: Services test — kube backup does not leak plaintext**

Extend `ServicesValidationAndSecurityTests` TC-B06 or add TC-B06b:

```swift
@Test("TC-B06b: kubeconfig YAML not exported in plaintext")
func testDataPortKubeConfigNotPlaintext() async throws { /* assert encrypted blob, not "apiVersion:" */ }
```

- [ ] **Step 4: Run tests — PASS**

- [ ] **Step 5: Commit:** `feat(dataport): import kube_config rows on restore`

---

### Task 4: Create-service parity with inspector

**Files:**
- Modify: `CreateServiceContextualFormView.swift`
- Modify: `CreateServicePayloadBuilder.swift`
- Modify: `CreateServiceSheet.swift`
- Test: `ServicesValidationAndSecurityTests.swift`

**Interfaces:**
- Consumes: `KubeConfigViewModel.sanitizedProviderContext(storedProviderContext:)`, `testConnection(storedProviderContext:)`

- [ ] **Step 1: Write failing validation tests**

```swift
@Test("TC-B08: Create K8s form invalid without kubeconfig selection")
func testCreateKubernetesFormRequiresKubeConfig() {
    let inputs = CreateServicePayloadBuilder.DraftInputs(/* kubernetes, targetName set, selectedKubeConfigID nil */)
    #expect(CreateServicePayloadBuilder.isFormValid(inputs: inputs) == false)
}

@Test("TC-B09: Create K8s form requires at least one complete port mapping")
func testCreateKubernetesFormRequiresPorts() {
    // temporaryPorts with empty or half-filled rows → false
    // one row local 5432 remote 5432 → true (with other fields valid)
}
```

- [ ] **Step 2: Tighten `isFormValid` for `.kubernetes`**

```swift
case .kubernetes:
    let targetOK = !inputs.kubeDraft.targetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    let kubeConfigOK = inputs.selectedKubeConfigID != nil
    let hasCompletePort = inputs.temporaryPorts.contains { item in
        guard let l = Int(item.local.trimmingCharacters(in: .whitespacesAndNewlines)),
              let r = Int(item.remote.trimmingCharacters(in: .whitespacesAndNewlines)),
              l > 0, l <= 65535, r > 0, r <= 65535 else { return false }
        return true
    }
    let contextOK = !inputs.kubeDraft.context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    return targetOK && kubeConfigOK && hasCompletePort && contextOK
```

- [ ] **Step 3: Replace empty `onConfigChanged` in create form**

Mirror `InspectorKubernetesFormSection`:

```swift
onConfigChanged: {
    let sanitized = kubeConfigVM.sanitizedProviderContext(storedProviderContext: kubeDraft.context)
    if kubeDraft.context != sanitized { kubeDraft.context = sanitized }
    kubeConfigVM.testConnection(storedProviderContext: kubeDraft.context)
}
```

Add `.onChange(of: kubeDraft.context)` in create form section to call `kubeConfigVM.testConnection(storedProviderContext: kubeDraft.context)` (debounce optional — reuse existing VM task).

- [ ] **Step 4: `CreateServiceSheet` — ensure configs loaded on details step**

```swift
.onChange(of: currentStep) { _, step in
    if step == .fillDetails && selectedProvider == .kubernetes {
        Task { await kubeConfigVM.loadConfigs(preferredSelectionID: kubeConfigVM.selectedKubeConfigID) }
    }
}
```

- [ ] **Step 5: Sanitize context in `buildPayload`**

Before assigning `kubeContext`, run `KubeConfigYAMLParser.resolveContextName` against selected config content from VM or re-parse — prefer calling a package-visible helper on `KubeConfigViewModel` or duplicate one-liner parser call with materialized YAML from `availableKubeConfigs`.

- [ ] **Step 6: Run TC-B08/B09 — PASS**

- [ ] **Step 7: Commit:** `fix(k8s): align create-service validation with inspector`

---

### Task 5: Re-validate when context changes (inspector)

**Files:**
- Modify: `InspectorKubernetesFormSection.swift`

- [ ] **Step 1: Add onChange on context binding**

After `KubeConnectionSettingsView`, or inside binding `set`:

```swift
set: {
    provider.kubeContext = $0.isEmpty ? nil : $0
    onFieldChanged()
    kubeConfigVM.testConnection(storedProviderContext: provider.kubeContext)
}
```

- [ ] **Step 2: Manual check** — switch context, badge updates within ~4s.

- [ ] **Step 3: Commit:** `fix(k8s): re-test cluster when context changes`

---

### Task 6: Legacy `customKubeConfigPath` cleanup

**Files:**
- Modify: `KubeConfigMaterializer.swift`
- Modify: `docs/specs/06-services.md` (DATA-01 section)
- Test: keep existing `ServicesValidationAndSecurityTests` custom path test if still valid

**Decision:** Keep DB column + export field for backward compatibility; **document** that app uses `kubeConfigID` + Settings global kube path only. Materializer order: `kubeConfigID` (DB) → legacy `customKubeConfigPath` → default.

- [ ] **Step 1: Add code comment in `KubeConfigMaterializer`**

```swift
// ponytail: customKubeConfigPath is legacy import-only; no UI writes this field.
```

- [ ] **Step 2: Update spec DATA-01** — column exists in `Provider+Record`; mark issue resolved or narrowed.

- [ ] **Step 3: Commit:** `docs(k8s): clarify customKubeConfigPath legacy semantics`

---

### Task 7: Remove dead `KubeTargetType.prefix` (optional)

**Files:**
- Modify: `KubeTargetType.swift`
- Grep usages; delete `prefix` if zero references.

- [ ] **Step 1: `rg '\\.prefix' Kuma/` — only enum**

- [ ] **Step 2: Delete property — build**

- [ ] **Step 3: Commit:** `chore(k8s): remove unused KubeTargetType.prefix`

---

### Task 8: Optional target preflight before port-forward (P3)

**Files:**
- Create: `Kuma/Core/Kubernetes/KubeTargetPreflight.swift` (or extend `KubeConnectionValidator`)
- Modify: `KubernetesRunner.swift`
- Test: `ServicesValidationAndSecurityTests.swift` with mocked subprocess **or** unit test on argument builder only

- [ ] **Step 1: Implement lightweight check**

```swift
enum KubeTargetPreflight {
    static func resourceExists(
        kubectlPath: String,
        kubeconfigPath: String?,
        context: String?,
        namespace: String?,
        targetType: KubeTargetType,
        name: String
    ) async throws -> Bool
}
```

Use `kubectl get <listResource>/<name> -o name` with same flags as runner; timeout 4s.

- [ ] **Step 2: Call from `KubernetesRunner.start` when `usePattern == false`** (exact name only; pattern path already lists).

- [ ] **Step 3: On failure, throw `ServiceExecutionError.invalidConfiguration` with kubectl stderr snippet in pipeline log.

- [ ] **Step 4: One unit test for URL/args assembly if full subprocess too heavy in CI.

- [ ] **Step 5: Commit:** `feat(k8s): preflight exact target before port-forward`

---

### Task 9: Full verification & doc touch-up

**Files:**
- Modify: `docs/testing/05-data-port-test-matrix.md` (TC-C20, TC-C21, TC-B07)
- Modify: `docs/testing/06-services-test-matrix.md` (TC-B08, TC-B09)

- [ ] **Step 1: Run full test suite**

```bash
xcodebuild test -scheme Kuma -destination 'platform=macOS' 2>&1 | tee /tmp/kuma-test.log | tail -50
```

Expected: **TEST SUCCEEDED**

- [ ] **Step 2: Update test matrices**

- [ ] **Step 3: Commit:** `test: document kubernetes provider cleanup matrix`

---

## Self-review (spec coverage)

| Audit item | Task |
|------------|------|
| Service/deployment port-forward + pattern | Task 0 |
| DataPort kube_config export/import | Tasks 1–3 |
| Create validation + onConfigChanged | Task 4 |
| Context change re-validation | Task 5 |
| customKubeConfigPath legacy | Task 6 |
| Dead `prefix` | Task 7 |
| Preflight target (optional) | Task 8 |
| Typed `kubeTargetType` on Provider | **Out of scope** (JSON + GRDB string; defer) |
| ProcessRegistry / SSH encryption | **Out of scope** (other providers sprint) |

**Placeholder scan:** No TBD steps; each task has concrete paths and test names.

**Type consistency:** `encryptedConfigContent` used consistently in export/import and tests.

---

## Suggested commit order (7–9 commits)

1. `fix(k8s): port-forward discovery for service and deployment`
2. `feat(dataport): extend ExportKubeConfig for encrypted YAML`
3. `feat(dataport): export/import referenced kube_config`
4. `fix(k8s): align create-service validation with inspector`
5. `fix(k8s): re-test cluster when context changes`
6. `docs(k8s): legacy customKubeConfigPath + test matrices`
7. Optional: `feat(k8s): preflight exact target before port-forward`

---

## Execution handoff

Plan saved to `docs/superpowers/plans/2026-09-22-kubernetes-provider-cleanup.md`.

**Two execution options:**

1. **Subagent-Driven (recommended)** — one fresh subagent per task, review between tasks.
2. **Inline Execution** — same session, batches Task 0→3 then 4→6, checkpoint with you.

Which approach do you want?
