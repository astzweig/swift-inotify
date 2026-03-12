# ``TaskCLI``

The build tool for the Swift Inotify project.

## Overview

`TaskCLI` is a small command-line executable (exposed as `task` in `Package.swift`) that automates project-level workflows. Its primary purpose is running the integration test suite inside a Linux Docker container, so you can validate the inotify-dependent code on the correct platform even when developing on macOS.

### Running the Tests

```bash
swift run task test
```

This launches a `swift:latest` Docker container with the repository mounted at `/code`, then executes two test passes:

1. All tests **except** `InotifyLimitTests` — the regular integration suite.
2. Only `InotifyLimitTests` (with `--skip-build`) — tests that manipulate system-level inotify limits and must run in isolation.

The container is started with `--security-opt systempaths=unconfined` so that the limit tests can write to `/proc/sys/fs/inotify/*`.

### Verbosity

Pass one or more `-v` flags to increase log output:

| Flag | Level |
|------|-------|
| *(none)* | `notice` |
| `-v` | `info` |
| `-vv` | `debug` |
| `-vvv` | `trace` |

### Prerequisites

Docker must be installed and running on the host machine. The container uses the `linux/arm64` platform by default.

## Topics

### Commands

- ``Command``
- ``TestCommand``

### Configuration

- ``GlobalOptions``
