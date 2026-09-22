# Kuma

Native macOS app for managing local development services — Kubernetes port-forwards, Docker/Podman, shell, SSH tunnels, health checks, and more — organized by workspace.

**Distribution:** [GitHub Releases](https://github.com/nsrvel/Kuma/releases) (not the Mac App Store).

## Requirements

- **macOS 14** (Sonoma) or later
- For building from source: **Xcode 16+** with Swift 6

Optional CLI tools (detected at runtime): `kubectl`, `docker`, `podman`, `ssh`, etc.

## Install (recommended)

1. Open [Releases](https://github.com/nsrvel/Kuma/releases) and download the latest `Kuma-x.y.dmg`.
2. Open the DMG and drag **Kuma** to **Applications**.
3. First launch: if macOS blocks the app (unsigned/ad-hoc build), open **System Settings → Privacy & Security** and choose **Open Anyway**, or right-click the app → **Open**.

> Signed/notarized Developer ID builds may be added later; until then, Gatekeeper warnings are expected for downloaded builds.

## Build from source

```bash
git clone https://github.com/nsrvel/Kuma.git
cd Kuma
open Kuma.xcodeproj
# Run (⌘R) or:
xcodebuild -scheme Kuma -destination 'platform=macOS' build
```

### Run tests

```bash
xcodebuild -scheme Kuma -destination 'platform=macOS' test
```

### Build a DMG locally

```bash
chmod +x Scripts/make-dmg.sh
./Scripts/make-dmg.sh
# Output: dist/Kuma-<version>.dmg
```

### Publish a GitHub Release (maintainers)

CI runs on every push/PR to `main` (build + test on **macOS 15** with **Xcode 16**).

To ship a DMG to [Releases](https://github.com/nsrvel/Kuma/releases), push a version tag:

```bash
git tag v1.0.0   # match CFBundleShortVersionString when possible
git push origin v1.0.0
```

The **Release** workflow (`.github/workflows/release.yml`) builds `dist/Kuma-*.dmg` and attaches it to the new GitHub Release with auto-generated notes.

## Project layout

| Path | Purpose |
|------|---------|
| `Kuma/` | App source (Domain, Core, Stores, Presentation) |
| `KumaTests/` | Swift Testing suites |
| `docs/specs/` | Feature specs & invariants |
| `docs/testing/` | Test matrices |
| `Scripts/` | DMG packaging & maintainer utilities |

## Contributing

Issues and PRs welcome on GitHub. For larger changes, check `docs/specs/` and existing patterns in `.agents/AGENTS.md`.

## License

MIT — see [LICENSE](LICENSE).
