# Kuma — Engineering Rules

> **Kuma** is a native macOS SwiftUI app for managing local dev services (K8s, Docker, SSH, Shell, etc). Target: macOS 14+, Swift 6 Strict Concurrency.

---

## 1. Architecture Boundaries

```
App/              → @main entry, AppDelegate
Domain/           → Pure Swift models, enums, protocols (ZERO dependencies)
  ├── Models/
  ├── Enums/
  ├── Protocols/
  └── Repositories/
Data/             → GRDB SQLite persistence
  ├── Database/
  ├── Migrations/
  ├── Entities/
  ├── Repositories/
  └── Security/
Core/             → Backend engines (non-UI)
  ├── Process/
  ├── Streams/
  ├── Environment/
  ├── Network/
  └── ...
Stores/           → @Observable state bridge
Presentation/     → SwiftUI views
  ├── Navigation/
  ├── Theme/
  └── Features/
Lib/              → Shared utilities & extensions
Resources/        → Assets, sounds, seed data
```

- **Layer flow**: `Presentation/` → `Stores/` → `Core/` & `Data/`
- **No flat file dumping** — every layer uses topic-specific sub-folders.

---

## 2. Swift 6 & Concurrency

- Swift 6 **Strict Concurrency** enabled. All `@Sendable` boundaries respected.
- State driven by **`ServiceExecutionState` enum** (`.stopped`, `.starting`, `.running`, `.stopping`, `.failed`). Multi-boolean flags forbidden.
- **`ServiceAggregate`** root model bundles Service + Providers + Ports + Secrets. No scattered multi-dictionary state.
- Domain models use **Enums with Associated Values** for polymorphic data. Fat optional structs forbidden.

---

## 3. Process Safety

- Subprocesses MUST `setpgid(0, 0)` & register in `ProcessRegistry`.
- Orphan killer: `SIGINT` → `SIGTERM` → `SIGKILL`.
- All `Pipe()` / `FileHandle` use explicit `defer` close.
- Log streams via `AsyncStream<String>` + `LogCoalescer` (max 5 flushes/sec, 100-entry FIFO RingBuffer).

---

## 4. Logging & Security

- Use `os.Logger` only. **`print()` is forbidden** in production code.
- Secrets encrypted via **AES-256-GCM** in `vault_secrets` table. No plain-text secrets in JSON.
- File access uses **Security-Scoped Bookmarks** persisted in SQLite.

---

## 5. SwiftUI & UI

- Stores observed via `@Environment`. **No ViewModels** (unless multi-step wizard).
- Views max **~150 lines**. Decompose into `Components/`.
- Scrollable lists use `LazyVStack` / `LazyVGrid`.
- Images downsampled via `CGImageSourceCreateThumbnailAtIndex`, cached with `NSCache`.
- All views include `#Preview` with mock data (zero DB/Process in previews).
- Respect `accessibilityReduceMotion` & provide `accessibilityLabel` on icon-only buttons.

---

## 6. Workflow

- **One task at a time**. Plan → Code → Verify → Approve → Next.
- Reference **KumaV3** for UI/UX design matching.
- Reference **KumaV4** for architecture & process patterns.
- No code written without user direction.
