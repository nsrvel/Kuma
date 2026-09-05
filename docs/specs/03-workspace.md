# Feature Spec 03: Workspace Management & Avatar Storage

> **Status:** Draft / Pending Review  
> **Target Version:** macOS 14+ (SwiftUI, Swift 6 Concurrency)  
> **Source Files:**  
> - `Kuma/Domain/Models/Workspace.swift`  
> - `Kuma/Core/Database/Records/Workspace+Record.swift`  
> - `Kuma/Core/Database/Repositories/WorkspaceRepository.swift`  
> - `Kuma/Core/Storage/WorkspaceImageStore.swift`  
> - `Kuma/Stores/WorkspaceStore.swift`  
> - `Kuma/Presentation/Components/WorkspaceAvatarView.swift`  
> - `Kuma/Presentation/Features/Workspace/Views/SidebarWorkspaceRow.swift`  
> - `Kuma/Presentation/Features/Workspace/Views/WorkspaceSwitcherPopover.swift`  
> - `Kuma/Presentation/Features/Workspace/Views/WorkspaceFormSheet.swift`  
> - `Kuma/Presentation/Features/Workspace/Views/Components/InactiveWorkspaceRow.swift`  
> - `Kuma/Presentation/Features/Workspace/Views/Components/NewWorkspaceBottomButton.swift`  
> - `Kuma/Presentation/Features/Workspace/Views/Components/WorkspaceAvatarPickerView.swift`  
> - `Kuma/Presentation/Features/Workspace/Views/Components/WorkspaceDangerZoneSection.swift`  
> **Test Suite Target:** `KumaTests/Features/Workspace/`  
> - `WorkspaceInitialStateTests.swift` (Kategori A: Baseline Default Workspace & Init)  
> - `WorkspaceValidationAndSecurityTests.swift` (Kategori B: Name validation, Image downsampling, POSIX permissions, Base64 roundtrip)  
> - `WorkspacePersistenceAndSyncTests.swift` (Kategori C: GRDB CRUD, Cascade deletion, Reordering sortOrder, Concurrency)  
> - `WorkspaceImageStoreLifecycleTests.swift` (Kategori D: Managed storage directory, Image caching, Atomic writes, Image deletion)  
> - `WorkspaceEdgeCasesAndErrorTests.swift` (Kategori E: Corrupted images, Missing file fallbacks, Rapid switching, Sole workspace deletion guard)  
> - `WorkspaceVisualTests.swift` (Kategori F: Headless SwiftUI views, Switcher popover, Form sheet modal, Avatar gradients, HIG compliance)  
> - `KumaTests/Harness/WorkspaceTestHarness.swift` (Shared In-Memory SQLite & Temp Files Test Harness)  

---

## 1. High-Level Flow (Architecture & State Flow)

```mermaid
graph TD
    User([User in Sidebar]) --> Row[SidebarWorkspaceRow]
    Row --> Popover[WorkspaceSwitcherPopover]

    subgraph SwitcherPopover [Workspace Switcher Canvas]
        Popover --> ActiveBox[Active Workspace Box: Name, Avatar, Settings Gear]
        Popover --> InactiveList[Inactive Workspaces ScrollView: ⌘1-⌘9 Shortcuts, Hover, ContextMenu]
        Popover --> NewBtn[New Workspace... Bottom Button]
    end

    ActiveBox -->|Click Settings / Context Menu| FormSheetEdit[WorkspaceFormSheet: mode .edit]
    InactiveList -->|Click Row / Shortcut| SwitchAction[WorkspaceStore.selectWorkspace]
    InactiveList -->|Context Menu: Edit| FormSheetEdit
    InactiveList -->|Context Menu: Delete| DeleteConfirm[AlertService.shared.confirmDelete]
    NewBtn -->|Click| FormSheetCreate[WorkspaceFormSheet: mode .create]

    subgraph FormSheetModal [Workspace Form Sheet]
        FormSheetCreate & FormSheetEdit --> AvatarPicker[WorkspaceAvatarPickerView: Avatar, Hover Camera, OpenPanel]
        FormSheetCreate & FormSheetEdit --> NameField[KumaTextField: Workspace Name autofocus]
        FormSheetEdit --> DangerZone[WorkspaceDangerZoneSection: Delete button if count > 1]
    end

    AvatarPicker -->|Choose Image| ImgStore[WorkspaceImageStore.shared.saveWorkspaceImage]
    ImgStore -->|Hardware ImageIO Downsample 512px| LocalPNG[Application Support/Kuma/Workspaces/Images/{id}.png]
    ImgStore -->|Atomic Write & Cache Invalidation| DiskWrite[Atomic Disk Write]

    FormSheetModal -->|Submit / Save| StoreMutation[WorkspaceStore: addWorkspace / updateWorkspace]
    StoreMutation --> Repository[WorkspaceRepository]
    Repository --> GRDB[(GRDB SQLite: Table 'workspace')]
    StoreMutation --> Defaults[(UserDefaults: kuma.selectedWorkspaceId.storage)]

    DeleteConfirm -->|Confirm Delete| DeleteAction[WorkspaceStore.deleteWorkspace]
    DeleteAction --> CascadeDB[SQLite Cascade Delete: Services & Providers]
    DeleteAction --> PurgeAvatar[WorkspaceImageStore.deleteImage]
    DeleteAction --> FallbackActive[Auto-select remaining first workspace]
```

---

## 2. Machine Deterministic State & Transition Matrix

### A. Workspace Selection & Lifecycle State

| Current State | Trigger / Event | Guard / Precondition | Next State | Persistence Actions |
| :--- | :--- | :--- | :--- | :--- |
| **Uninitialized** | App launches / `WorkspaceStore.init()` | Database empty | **Default Workspace Created** | Inserts `Workspace.defaultWorkspace` with localized user name; saves ID to `UserDefaults`. |
| **Uninitialized** | App launches / `WorkspaceStore.init()` | Database has $\ge 1$ workspaces | **Workspaces Loaded** | Loads ordered by `sortOrder ASC, createdAt ASC`; selects persisted ID or defaults to first. |
| **Active Selection ($W_A$)** | User clicks $W_B$ in popover | $W_B \in \text{workspaces}$ | **Active Selection ($W_B$)** | Updates `selectedWorkspaceId = W_B.id`; writes to `UserDefaults`. |
| **Active Selection ($W_A$)** | User presses ⌘+N | $1 \le N \le \min(\text{count}, 9)$ | **Active Selection ($W_N$)** | Switches immediately to $N$-th workspace in ordered array. |
| **Viewing Switcher** | User taps "+" button | None | **Create Sheet Open** | `showCreateSheet = true`; form initial state clean. |
| **Viewing Switcher** | User taps Settings gear / Edit | Target workspace $W$ exists | **Edit Sheet Open** | `workspaceToEdit = W`; pre-populates name and avatar preview. |
| **Create Sheet Open** | User submits valid name | `trimmedName.count > 0` | **Active Selection ($W_{\text{new}}$)** | Generates UUID; saves avatar; inserts into SQLite; appends to `workspaces`; auto-selects $W_{\text{new}}$. |
| **Create Sheet Open** | User submits blank name | `trimmedName.isEmpty` | **Create Sheet Open (Error)** | Blocks submission; displays validation error or keeps button disabled. |
| **Edit Sheet Open** | User updates name / avatar | `trimmedName.count > 0` | **Active Selection ($W$)** | Writes downsampled avatar; updates `updatedAt = Date()`; executes `repository.update(W)`. |
| **Edit Sheet Open** | User removes avatar photo | Existing avatar present | **Edit Sheet Open** | Unlinks `imagePath`; deletes managed PNG file from disk; invalidates cache. |
| **Active / Inactive ($W$)**| User deletes $W$ | `workspaces.count > 1` | **Workspace Deleted** | SQLite cascade delete; removes image file; if active, falls back to remaining `workspaces.first`. |
| **Sole Workspace ($W_1$)**| User attempts deletion | `workspaces.count == 1` | **Action Blocked** | UI hides/disables delete action (canDelete = false); invariant prevents 0-workspace state. |
| **Ordered List** | User reorders workspace ($i \to j$) | Valid array indices | **Reordered List** | Updates `sortOrder` for all elements; writes batch `UPDATE` to SQLite. |

---

## 3. Invariant Rules (Kontrak Baku / Non-Negotiables)

1. **Non-Zero Workspaces Invariant (Never Zero)**:
   - The application MUST never reach a state with 0 workspaces. If the database is empty on boot, `Workspace.defaultWorkspace` MUST be inserted synchronously/deterministically.
   - Deletion of the final remaining workspace is strictly prohibited. The UI must hide/disable delete controls when `workspaces.count <= 1`, and the store must reject deletion requests if only 1 workspace exists.
2. **Active Workspace Fallback Guarantee**:
   - `WorkspaceStore.activeWorkspace` MUST always resolve to a valid workspace as long as `workspaces` is not empty (`workspaces.first(where: { $0.id == selectedWorkspaceId }) ?? workspaces.first`).
   - If the currently selected workspace is deleted, `selectedWorkspaceId` MUST immediately update to the first available remaining workspace.
3. **Hardware-Accelerated Avatar Management & Sandbox Isolation**:
   - Avatars MUST NEVER be referenced by raw, arbitrary external paths that can become broken when the source file moves.
   - When an external image is selected via `NSOpenPanel`, `WorkspaceImageStore` MUST downsample it using ImageIO (`CGImageSourceCreateThumbnailAtIndex` max 512px) and save it atomically as `{workspaceID}.png` inside `Application Support/Kuma/Workspaces/Images/`.
   - In-memory caching MUST be backed by `NSCache` with bounded memory (`countLimit = 100`) and cleared on image mutations/deletions.
4. **Cascade Integrity & SQLite Persistence**:
   - Foreign key cascading is enabled in SQLite (`PRAGMA foreign_keys = ON`). Deleting a workspace record triggers automatic cascade deletion of all associated `service` and `provider` records.
   - Associated avatar images on disk must be cleaned up concurrently without leaving orphaned PNG files.
5. **Swift 6 Strict Concurrency & Actor Isolation**:
   - `WorkspaceStore` is strictly `@MainActor` isolated.
   - `WorkspaceRepository` conforms to `Sendable` via GRDB `DatabaseWriter` thread safety.
   - `WorkspaceImageStore` methods are nonisolated and thread-safe (`atomic` writes, `NSCache`).
6. **HIG Compliance & View Modularity (< 150 Lines)**:
   - Every SwiftUI view must stay under ~150 lines. Large sub-sections (e.g. `dangerZoneSection` in `WorkspaceFormSheet`) MUST be decomposed into modular components (`WorkspaceDangerZoneSection.swift`).
   - All interactive items (avatar picker, popover rows, bottom button) must have explicit accessibility labels and keyboard shortcuts (`⌘1-⌘9`, `ESC`, `Enter`).

---

## 4. Invariant Guardrails Mapping to Target Test Suite

| Guardrail ID | Invariant Guardrail | Target Test Suites | Failure Mode Prevented |
| :--- | :--- | :--- | :--- |
| **G-01** | Zero-Workspace Prevention & Default Seeding | `WorkspaceInitialStateTests` | App launching in a blank/unusable state without any workspace. |
| **G-02** | Active Selection Fallback on Deletion | `WorkspacePersistenceAndSyncTests` | Dead UI or nil unwraps when the currently active workspace is deleted. |
| **G-03** | Sole Workspace Delete Guard | `WorkspaceEdgeCasesAndErrorTests` | User deleting their last workspace and breaking all service parent foreign keys. |
| **G-04** | Hardware ImageIO Downsampling & Isolation | `WorkspaceValidationAndSecurityTests` | Gigabyte image files blowing up RAM or broken absolute image paths. |
| **G-05** | Atomicity of Disk Writes & Cache Sync | `WorkspaceImageStoreLifecycleTests` | Partial/corrupted PNG files on disk or stale avatar caches after avatar edits. |
| **G-06** | Foreign Key Cascade Cleanup | `WorkspacePersistenceAndSyncTests` | Orphaned service records or dangling image files left behind after deletion. |
| **G-07** | Deterministic Reordering & Sort Order | `WorkspacePersistenceAndSyncTests` | Workspaces reshuffling unpredictably across app launches. |
| **G-08** | Input Sanitization & Empty Name Prevention | `WorkspaceValidationAndSecurityTests` | Whitespace-only or empty workspace names saved in the database. |
| **G-09** | Base64 Backup & Restore Roundtrip | `WorkspaceValidationAndSecurityTests` | Avatar loss during workspace JSON export/import via DataPort. |
| **G-10** | Headless SwiftUI & HIG Modularity (< 150 lines) | `WorkspaceVisualTests` | Giant monolithic views breaking architecture rules, or broken accessibility labels. |
