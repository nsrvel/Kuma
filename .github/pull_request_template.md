## Summary

<!-- What changed and why? -->

## Checklist

- [ ] `xcodebuild -scheme Kuma -destination 'platform=macOS' test` passes locally (or CI is green)
- [ ] DB migration included harness updates (`DataPortTestHarness`, `ServicesTestHarness`) if applicable
- [ ] New/changed Services SwiftUI views respect the ~150 line limit (or test exception documented)
- [ ] No real secrets in JSON samples, exports, or committed fixtures

## Test plan

<!-- Steps you used to verify -->
