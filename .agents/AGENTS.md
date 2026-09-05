# Kuma — Engineering Rules & Architecture Standard

> **Kuma** is a native macOS SwiftUI app for managing local dev services (K8s, Docker, Podman, SSH, Shell, Tunnels, Health Checks).  
> Target: **macOS 14+**, **Swift 6 Strict Concurrency**, Apple Human Interface Guidelines (HIG).

---

## 1. Directory Structure & Layer Boundaries

```
Kuma/
├── App/                  → @main entry, AppDelegate, AppCoordinator, KumaCommands
├── Domain/               → Pure Swift models, enums (ZERO UI / DB dependencies)
│   ├── Enums/            → Domain categories, options, and polymorphic types
│   └── Models/           → Pure entities (Service, Provider, ServicePortMapping, etc.)
├── Core/                 → Non-UI business engines & persistence layer
│   ├── Audio/            → System audio feedback & sound manager
│   ├── Database/         → GRDB SQLite persistence
│   │   ├── Records/      → SQLite Table Record definitions (GRDB models)
│   │   └── Repositories/ → DB Repositories & Protocols (co-located)
│   ├── DataPort/         → Export/Import engine & backup encoders
│   ├── Environment/      → Path resolvers & system binary execution paths
│   ├── Notifications/    → System notifications & AlertService payload bus
│   └── Security/         → CryptoVault (AES-256-GCM encryption)
├── Stores/               → @Observable state bridge across views (e.g. WorkspaceStore)
├── Lib/                  → Shared utilities & Foundation/AppKit extensions
└── Presentation/         → SwiftUI views & visual components
    ├── Components/       → Global reusable components & FormKit (Cross-feature)
    │   └── FormKit/      → KumaTextField, KumaSecureField, KumaFilePickerField, etc.
    ├── Theme/            → Colors, fonts, radius, spacing design system tokens
    └── Features/         → Topic-specific feature modules
        └── [FeatureName]/ (e.g. Services)
            ├── Models/          → Presentation DTOs & form draft structs (e.g. ServiceInspectorDrafts)
            ├── ViewModels/      → Domain @Observable @MainActor ViewModels
            └── Views/           → Sub-containers & screens grouped by context:
                ├── Deck/        → Main grid/list view canvas, toolbar, and deck components
                ├── Inspector/   → Detail sidebar & single-scroll inspector sections
                ├── CreateService/ → Multi-step creation sheet modals
                └── Forms/       → Modular provider configuration sub-forms ([Provider]/)
```

### Layer Rules:
- **Dependency Flow**: `Presentation/` → `Stores/` → `Core/` → `Domain/`. Lower layers NEVER import higher layers.
- **No Flat File Dumping**: Every layer and subfolder MUST use topic-specific subdirectories.
- **Components Containment**:
  - Reusable across multiple features → Place in `Presentation/Components/` (or `Presentation/Components/FormKit/`).
  - Feature-level shared widgets → Place in `Presentation/Features/[FeatureName]/Views/[SubFolder]/Components/`.
  - Feature-level reusable forms → Place in `Presentation/Features/[FeatureName]/Views/Forms/[SubCategory]/`.

---

## 2. Swift 6, Concurrency & State

- **Strict Concurrency**: Swift 6 Strict Concurrency is enabled. All `@Sendable` boundaries and actor isolations (`@MainActor`, `actor`) must be strictly respected.
- **Enums Over Multi-Booleans**: Service and UI states MUST be driven by discrete Enums with associated values (e.g., `ServiceExecutionState`), never scattered multi-boolean flags (`isLoading`, `isStarting`, `isError`, etc.).
- **URL Path Modernization**: Never use `.path` on `URL` in macOS 14+. Always use `.path(percentEncoded: false)`.
- **Atomic Operations**: File writes for backups and exports must use atomic writing.

---

## 3. SwiftUI & View Architecture

- **View Size Limit**: Views MUST NOT exceed **~150 lines**. Any complex layout or card MUST be decomposed into `Views/Components/`.
- **Form Architecture**: Multi-step forms (e.g. `CreateServiceSheet`) must separate step views and general settings into separate modular components.
- **Stores & Observation**:
  - Global app stores are injected and observed via `@Environment(WorkspaceStore.self)` or `@Bindable`.
  - Feature ViewModels use `@Observable` and `@MainActor`.
- **No ViewModels for Simple Views**: Simple display views or sheets should consume Stores or Snapshot models directly without redundant intermediate ViewModels.
- **Lists & Performance**:
  - Large scrollable lists or grids must use `LazyVStack` or `LazyVGrid`.
  - Heavy tree navigation algorithms (e.g. flattening node hierarchies) belong in the ViewModel, not inside the SwiftUI `body`.
- **Previews**: All views must include `#Preview` with clean mock data (zero active DB queries or process executions during preview).
- **Accessibility & HIG**:
  - Icon-only buttons must provide an `.accessibilityLabel(...)`.
  - Animated transitions must respect spring physics (`response: 0.2-0.35`, `dampingFraction: 0.7-0.88`).

---

## 4. Database & Persistence (GRDB)

- **Record Separation**: GRDB `FetchableRecord` & `PersistableRecord` structs belong in `Core/Database/Records/`.
- **Protocol Co-location**: DB repository protocols (e.g. `ServiceRepositoryProtocol`) remain co-located alongside their implementation in `Core/Database/Repositories/`.
- **Security & Vault**: Plaintext passwords, tokens, and private SSH keys must be encrypted using `CryptoVault.shared.encrypt(plainText:)` before persisting to SQLite.

---

## 5. Process Safety & Subprocesses

- Subprocesses MUST call `setpgid(0, 0)` and register in `ProcessRegistry`.
- Orphan killer escalation: `SIGINT` → `SIGTERM` → `SIGKILL`.
- All `Pipe()` and `FileHandle` instances must use explicit `defer { try? handle.close() }`.
- Production code MUST use `os.Logger`. **`print()` is forbidden in production code.**

---

## 6. Workflow & Development Protocol

1. **Mandatory Implementation Plan**: An `implementation_plan.md` artifact MUST ALWAYS be created and reviewed before writing any production code, tests, or executing refactorings. The plan must clearly outline architectural decisions, file changes, and verification strategies.
2. **Step-by-Step Approval**: No code modification or multi-file creation without explicit user review and approval of the spec, test matrix, and implementation plan.
3. **Standard Verifications**: Always run `xcodebuild -scheme Kuma -destination 'platform=macOS' test` to verify 100% test suite pass after any architectural change.
4. **Reference Targets**:
   - UI/UX aesthetics & visual fidelity → Match **KumaV3** references.
   - Core architecture, safety & concurrency → Match **KumaV4** patterns.

---

## 7. Critical Thinking & Architectural Evaluation

- **Never Blindly Comply**: Do not blindly follow instructions without first critically evaluating architectural, performance, and UI/UX implications.
- **Provide Better Alternatives**: If a requested change degrades performance (e.g., unnecessary `LazyVStack` on small forms, heavy GPU blurs, synchronous main-thread I/O), explain the trade-offs clearly and propose the technically superior solution before writing code.
- **Performance & Polish First**: Always prioritize 120fps smooth animations, battery/CPU efficiency, and macOS HIG principles over quick hacks.

