# Watching Directory Trees

Monitor an entire directory hierarchy for filesystem events.

## Overview

The Linux inotify API watches individual directories — it does not descend into subdirectories automatically. The ``Inotify/Inotify`` actor offers two convenience methods that handle the recursion for you.

### Recursive Watch

Call ``Inotify/Inotify/addRecursiveWatch(forDirectory:mask:)`` to walk the directory tree once and install a watch on every subdirectory that exists at the time of the call:

```swift
let inotify = try Inotify()
let descriptors = try await inotify.addRecursiveWatch(
    forDirectory: "/home/user/project",
    mask: [.create, .modify, .delete]
)
```

The returned array contains one watch descriptor per directory. Subdirectories created **after** this call are not covered.

### Automatic Subtree Watching

When you also want future subdirectories to be picked up, use ``Inotify/Inotify/addWatchWithAutomaticSubtreeWatching(forDirectory:mask:)`` instead:

```swift
let descriptors = try await inotify.addWatchWithAutomaticSubtreeWatching(
    forDirectory: "/home/user/project",
    mask: [.create, .modify, .delete]
)
```

Internally this listens for `CREATE` and `MOVED_TO` events carrying the ``InotifyEventMask/isDir`` flag and installs new watches with the same mask on the subdirectory and its subtree whenever one appears. Items that already exist inside such a subdirectory are reported with ``FileSystemEvent/synthesized`` set to `true`, since the kernel never produces events for them; a synthesized event may duplicate a kernel event for the same item.

When a directory is moved out of the watched tree, the watches on it and on its subdirectories are removed, so no events are reported under the stale path.

### Excluding Directories

When watching large trees you often want to skip certain subdirectories entirely — version-control metadata, build artefacts, dependency caches, and so on. Call ``Inotify/Inotify/exclude(names:)`` or ``Inotify/Inotify/exclude(patterns:)`` **before** adding a recursive or automatic-subtree watch:

```swift
let inotify = try Inotify()
await inotify.exclude(names: ".git", "node_modules", ".build")
await inotify.exclude(patterns: ".*", "*.tmp")

try await inotify.addWatchWithAutomaticSubtreeWatching(
    forDirectory: "/home/user/project",
    mask: .allEvents
)
```

Excluded names and patterns are matched against the last path component of each directory during resolution, against a directory that appears later before a watch is extended to it, and against every event, so you never receive events for excluded items. A pattern is matched the way the shell matches file names: `*` and `?` stand for any characters and `[…]` for a set of characters; a leading dot needs no special treatment.

### Choosing the Right Method

| Method | Covers existing subdirectories | Covers new subdirectories |
|--------|:----:|:----:|
| ``Inotify/Inotify/addWatch(path:mask:)`` | No | No |
| ``Inotify/Inotify/addRecursiveWatch(forDirectory:mask:)`` | Yes | No |
| ``Inotify/Inotify/addWatchWithAutomaticSubtreeWatching(forDirectory:mask:)`` | Yes | Yes |
