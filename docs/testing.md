# Testing

## Local (mirror CI)

From the repo root:

```bash
xcodebuild -scheme Kuma -resolvePackageDependencies -clonedSourcePackagesDirPath .spm

xcodebuild \
  -scheme Kuma \
  -destination 'platform=macOS' \
  -clonedSourcePackagesDirPath .spm \
  -derivedDataPath build/DerivedData \
  build-for-testing

NSUnbufferedIO=YES xcodebuild \
  -scheme Kuma \
  -destination 'platform=macOS' \
  -clonedSourcePackagesDirPath .spm \
  -derivedDataPath build/DerivedData \
  -maximum-test-execution-time-allowance 120 \
  test-without-building
```

Parallel test execution is enabled at the scheme level. Suites that touch global process state use Swift Testing `.serialized` and call `ProcessTestSupport.resetProcessWorld()` from suite `init()` where needed.

## CI

GitHub Actions job **Build & Test (macOS)** on `macos-15` / Xcode 16: SPM cache, DerivedData cache, 20-minute job timeout, up to 4 parallel test workers, 120s per-test allowance, and `TestResults.xcresult` uploaded on failure.

## Harnesses

Shared helpers live under `KumaTests/Harness/` (e.g. `ServicesTestHarness`, `KubectlTestFixture`, `ProcessTestSupport`).

## Conventions

- Write new `@Test` display names and comments in **English**.
- Prefix duplicate `TC-*` labels with a suite shorthand when the same ID appears in another file (e.g. `DataPort.C05`, `Runtime.D06`, `Runner.D08`).
