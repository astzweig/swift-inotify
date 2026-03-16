# ``InotifyTaskCLI``

The build tool for the Swift Inotify project.

## Overview

`TaskCLI` is a small command-line executable (exposed as `task` in `Package.swift`) that automates project-level workflows. Its primary purpose is running integration tests and generating documentation inside Linux Docker containers, so you can validate inotify-dependent code on the correct platform even when developing on macOS.

Because of a Swift Package Manager Bug in the [package dependency resolution][swiftpm-bug], the executable needs to be run using the `task.sh` shell script.

[swiftpm-bug]: https://github.com/swiftlang/swift-package-manager/issues/8482

### Running the Tests

```bash
./task.sh test
```

This launches a `swift:latest` Docker container with the repository mounted at `/code`, then executes two test passes:

1. All tests **except** `InotifyLimitTests` — the regular integration suite.
2. Only `InotifyLimitTests` (with `--skip-build`) — tests that manipulate system-level inotify limits and must run in isolation.

The container is started with `--security-opt systempaths=unconfined` so that the limit tests can write to `/proc/sys/fs/inotify/*`.

### Generating Documentation

```bash
./task.sh generate-documentation
```

This copies the project to a temporary directory, injects the `swift-docc-plugin` dependency via `swift package add-dependency` (if absent), and runs documentation generation inside a `swift:latest` Docker container. The resulting static sites are written to `./public/inotify/` and `./public/taskcli/`, ready for deployment to GitHub Pages.

The working tree is never modified — all changes happen in the temporary copy, which is cleaned up automatically.

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
- ``GenerateDocumentationCommand``

### Configuration

- ``GlobalOptions``

### Errors

- ``GenerateDocumentationError``
