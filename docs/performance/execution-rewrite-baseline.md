# Execution layer performance baseline

Record **before** and **after** the execution supervisor rewrite. Use a **Release** build (`Product → Archive` or `xcodebuild -configuration Release`).

## Setup

- 3 Kubernetes services running (port-forward only), same cluster/context as production use.
- No other heavy apps; note macOS version and machine model.

## Metrics (idle ~60s)

| Metric | Inspector closed | Inspector open (config, not Live Logs) |
|--------|------------------|----------------------------------------|
| Kuma CPU % (Activity Monitor) | | |
| Wakeups / sec | | |
| Thread count | | |
| Child processes (`pgrep -lf kubectl` count) | | |

## Commands

```bash
# Child kubectl processes
pgrep -lf kubectl | wc -l

# Sample Kuma PID CPU (replace PID)
ps -p <PID> -o %cpu,rss,thcount
```

## Before rewrite

| Date | Notes |
|------|-------|
| _fill manually_ | |

## After rewrite

| Date | Notes |
|------|-------|
| _fill manually_ | |
