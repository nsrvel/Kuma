# Contributing to Kuma

Thanks for your interest in Kuma. This is a native macOS SwiftUI app (macOS 14+, Swift 6, Xcode 16+).

## Workflow

1. Fork or branch from `main` (`feat/…`, `fix/…`, `chore/…`).
2. Open a **pull request**; wait for **CI** (Build & Test on macOS) to pass.
3. Maintainers use **squash merge** so `main` stays one commit per change.

## Verify locally

```bash
xcodebuild -scheme Kuma -destination 'platform=macOS' test
```

## Architecture (short)

- **Layers:** `Presentation` → `Stores` → `Core` → `Domain` (no upward imports).
- **Persistence:** GRDB in `Core/Database/`; encrypt secrets with `CryptoVault` before SQLite.
- **Processes:** subprocesses use `ProcessRegistry`, process groups, and `os.Logger` (no `print()` in production paths).
- **SwiftUI:** keep view files roughly under **150 lines**; split into `Views/Components/`.
- **Specs:** feature contracts live in [`docs/specs/`](docs/specs/); test matrices in [`docs/testing/`](docs/testing/).

Larger features should align with an existing spec or extend one in the same PR.

## Database migrations

If you add a schema migration, update isolated test harnesses in the same PR:

- [`KumaTests/Harness/DataPortTestHarness.swift`](KumaTests/Harness/DataPortTestHarness.swift)
- [`KumaTests/Harness/ServicesTestHarness.swift`](KumaTests/Harness/ServicesTestHarness.swift)

## DataPort / backups

Do not commit real kubeconfigs, SSH passwords, or ngrok tokens. Sample data belongs in [`docs/samples/`](docs/samples/) with fake hosts only.

## Maintainers

- **Social preview:** GitHub → Settings → General → upload [`docs/images/kuma-deck-screenshot.png`](docs/images/kuma-deck-screenshot.png).
- **Releases:** tag `v*` on green `main`; see README “Publish a GitHub Release”.
