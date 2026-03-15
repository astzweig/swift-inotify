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

Internally this listens for `CREATE` events carrying the ``InotifyEventMask/isDir`` flag and installs a new watch with the same mask whenever a subdirectory appears.

### Excluding Directories

When watching large trees you often want to skip certain subdirectories entirely — version-control metadata, build artefacts, dependency caches, and so on. Call ``Inotify/Inotify/exclude(names:)`` **before** adding a recursive or automatic-subtree watch:

```swift
let inotify = try Inotify()
await inotify.exclude(names: ".git", "node_modules", ".build")

try await inotify.addWatchWithAutomaticSubtreeWatching(
    forDirectory: "/home/user/project",
    mask: .allEvents
)
```

Excluded names are matched against the last path component of each directory during resolution and are also filtered from the event stream, so you never receive events for items whose name is on the exclusion list.

### Choosing the Right Method

| Method | Covers existing subdirectories | Covers new subdirectories |
|--------|:----:|:----:|
| ``Inotify/Inotify/addWatch(path:mask:)`` | No | No |
| ``Inotify/Inotify/addRecursiveWatch(forDirectory:mask:)`` | Yes | No |
| ``Inotify/Inotify/addWatchWithAutomaticSubtreeWatching(forDirectory:mask:)`` | Yes | Yes |
