# Inotify

A Swift wrapper around the Linux [inotify](https://man7.org/linux/man-pages/man7/inotify.7.html) API, built on modern Swift concurrency. It lets you watch individual files or directories for filesystem events, recursively monitor entire subtrees, and optionally have newly created subdirectories watched automatically.

Events are delivered as an `AsyncSequence`, so you can consume them with a simple `for await` loop.

## Adding Inotify to Your Project

Add the package dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/astzweig/swift-inotify.git", from: "1.0.0")
]
```

Then add `Inotify` to your target's dependencies:

```swift
.target(
    ...
    dependencies: [
        .product(name: "Inotify", package: "swift-inotify")
    ]
    ...
)
```

## Quick Start

```swift
import Inotify

let inotify = try Inotify()

// Watch a single file for modifications
try inotify.addWatch(path: "/tmp/some-existing-file.txt", mask: [.modify])

// Watch a single directory for file creations and modifications
try inotify.addWatch(path: "/tmp/watched", mask: [.create, .modify])

// Consume events as they arrive
for await event in await inotify.events {
    print("Event at \(event.path): \(event.mask)")
}
```

## Watching Subtrees

Inotify operates on individual watch descriptors, so monitoring a directory does not automatically cover its children. This library provides two convenience methods that handle the recursion for you.

### Recursive Watch

`addRecursiveWatch` walks the directory tree at setup time and installs a watch on every existing subdirectory:

```swift
try await inotify.addRecursiveWatch(
    forDirectory: "/home/user/project",
    mask: [.create, .modify, .delete]
)
```

Subdirectories created after the call are **not** watched.

### Automatic Subtree Watching

`addWatchWithAutomaticSubtreeWatching` does everything `addRecursiveWatch` does, and additionally listens for `CREATE` events with the `isDir` flag. Whenever a new subdirectory appears, a watch is installed on it automatically:

```swift
try await inotify.addWatchWithAutomaticSubtreeWatching(
    forDirectory: "/home/user/project",
    mask: [.create, .modify, .delete]
)
```

This is the most convenient option when you need full coverage of a growing directory tree.

## Excluding Items

You can tell the `Inotify` actor to ignore certain file or directory names. Excluded names are skipped during recursive directory resolution (so no watch is installed on them) and silently dropped from the event stream:

```swift
let inotify = try Inotify()

// Ignore version-control and build directories
await inotify.exclude(names: ".git", "node_modules", ".build")

try await inotify.addWatchWithAutomaticSubtreeWatching(
    forDirectory: "/home/user/project",
    mask: [.create, .modify, .delete]
)
```

Use `isExcluded(_:)` to check whether a name is currently on the exclusion list.

## Event Masks

`InotifyEventMask` is an `OptionSet` that mirrors the native inotify flags. You can combine them freely.

| Mask | Description |
|------|-------------|
| `.access` | File was read |
| `.attrib` | Metadata changed (permissions, timestamps, ...) |
| `.closeWrite` | File opened for writing was closed |
| `.closeNoWrite` | File **not** opened for writing was closed |
| `.create` | File or directory created in watched directory |
| `.delete` | File or directory deleted in watched directory |
| `.deleteSelf` | Watched item itself was deleted |
| `.modify` | File was written to |
| `.moveSelf` | Watched item itself was moved |
| `.movedFrom` | File moved **out** of watched directory |
| `.movedTo` | File moved **into** watched directory |
| `.open` | File was opened |

Convenience combinations: `.move` (`.movedFrom` + `.movedTo`), `.close` (`.closeWrite` + `.closeNoWrite`), `.allEvents`.

Watch flags: `.dontFollow`, `.onlyDir`, `.oneShot`.

Kernel-only flags returned in events: `.isDir`, `.ignored`, `.queueOverflow`, `.unmount`.

## Removing a Watch

Every `addWatch` variant returns one or more watch descriptors that you can use to remove the watch later:

```swift
let wd = try inotify.addWatch(path: "/tmp/watched", mask: .create)

// ... later
try inotify.removeWatch(wd)
```

## Build Tool

The package ships with a `task` executable (the `TaskCLI` target) that serves as the project's build tool. It automates running tests and generating documentation inside Linux Docker containers, so you can validate everything on the correct platform even when developing on macOS.

### Tests

```bash
swift run task test
```

Use `-v`, `-vv`, or `-vvv` to increase log verbosity. The command runs two passes: first all tests except `InotifyLimitTests`, then only `InotifyLimitTests` (which manipulate system-level inotify limits and need to run in isolation).

Docker must be installed and running on your machine.

### Documentation

Full API documentation is available as DocC catalogs bundled with the package. Generate them locally with:

```bash
swift run task generate-docs
```

Then open the files in the newly created `public` folder.
Or preview in Xcode by selecting **Product > Build Documentation**.

## Requirements

- Swift 6.0+
- Linux (inotify is a Linux-only API)
- Docker (for running the test suite via `swift run task test`)

## License

See [LICENSE](LICENSE) for details.
