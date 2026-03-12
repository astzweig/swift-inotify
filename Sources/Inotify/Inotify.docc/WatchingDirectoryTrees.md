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

### Choosing the Right Method

| Method | Covers existing subdirectories | Covers new subdirectories |
|--------|:----:|:----:|
| ``Inotify/Inotify/addWatch(path:mask:)`` | No | No |
| ``Inotify/Inotify/addRecursiveWatch(forDirectory:mask:)`` | Yes | No |
| ``Inotify/Inotify/addWatchWithAutomaticSubtreeWatching(forDirectory:mask:)`` | Yes | Yes |
