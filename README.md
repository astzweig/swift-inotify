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

`addWatchWithAutomaticSubtreeWatching` does everything `addRecursiveWatch` does, and additionally listens for `CREATE` and `MOVED_TO` events with the `isDir` flag. Whenever a subdirectory appears, whether created or moved in, a watch is installed on it and on its subdirectories automatically:

```swift
try await inotify.addWatchWithAutomaticSubtreeWatching(
    forDirectory: "/home/user/project",
    mask: [.create, .modify, .delete]
)
```

This is the most convenient option when you need full coverage of a growing directory tree.

Items that already exist inside a directory that appears this way never produce kernel events. The library reports them as if they had just appeared, using the same kind of event (`CREATE` or `MOVED_TO`), with `synthesized` set to `true`. A synthesized event may duplicate a kernel event for the same item, so consumers that act on events should tolerate seeing an item twice.

When a watched directory is moved out of the tree, the watches on it and on its subdirectories are removed, so no events are reported under the stale path.

## Excluding Items

You can tell the `Inotify` actor to ignore certain file or directory names, either exactly or by a shell pattern. Excluded items are skipped during recursive directory resolution (so no watch is installed on them), never get a watch when they appear later, and are silently dropped from the event stream:

```swift
let inotify = try Inotify()

// Ignore version-control and build directories
await inotify.exclude(names: ".git", "node_modules", ".build")

// Ignore every hidden item and every metadata directory of a NAS
await inotify.exclude(patterns: ".*", "@eaDir")

try await inotify.addWatchWithAutomaticSubtreeWatching(
    forDirectory: "/home/user/project",
    mask: [.create, .modify, .delete]
)
```

A pattern is matched against an item's own name, not its path, the way the shell matches file names: `*` and `?` stand for any characters and `[…]` for a set of characters. Use `isExcluded(_:)` to check whether a name is currently excluded.

## Event Masks

`InotifyEventMask` is an `OptionSet` that mirrors the native inotify flags. You can combine them freely.

The mask lives in the separate `InotifyMask` product, which has no Linux dependency. Depend on it alone where code only stores or compares masks and must build or be tested on other platforms; `Inotify` re-exports it.

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

When the kernel queue overflows, events are lost and a single event with `.queueOverflow` is delivered instead. It has no path and a watch descriptor of `-1`; rescan the watched directories if you must not miss changes.

## Removing a Watch

Every `addWatch` variant returns one or more watch descriptors that you can use to remove the watch later:

```swift
let wd = try inotify.addWatch(path: "/tmp/watched", mask: .create)

// ... later
try inotify.removeWatch(wd)
```

## Build Tool

The package ships with a `task` executable (the `TaskCLI` target) that serves as the project's build tool. It automates running tests and generating documentation inside Linux Docker containers, so you can validate everything on the correct platform even when developing on macOS.
Because of a Swift Package Manager Bug in the [package dependency resolution][swiftpm-bug], the executable needs to be run using the `task.sh` shell script.

[swiftpm-bug]: https://github.com/swiftlang/swift-package-manager/issues/8482

### Tests

```bash
./task.sh test
```

Use `-v`, `-vv`, or `-vvv` to increase log verbosity. The command runs two passes: first all tests except `InotifyLimitTests`, then only `InotifyLimitTests` (which manipulate system-level inotify limits and need to run in isolation).

Docker must be installed and running on your machine.

### Documentation

Full API documentation is available as DocC catalogs bundled with the package. Generate them locally with:

```bash
./task.sh generate-docs
```

Then open the files in the newly created `public` folder.
Or preview in Xcode by selecting **Product > Build Documentation**.

## Requirements

- Swift 6.0+
- Linux (inotify is a Linux-only API)
- Docker (for running the test suite via `swift run task test`)

## License

See [LICENSE](LICENSE) for details.
