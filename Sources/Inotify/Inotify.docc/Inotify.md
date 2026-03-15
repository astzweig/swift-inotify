# ``Inotify``

Monitor filesystem events on Linux using modern Swift concurrency.

## Overview

The Inotify library wraps the Linux [inotify](https://man7.org/linux/man-pages/man7/inotify.7.html) API in a Swift-native interface built around actors and async sequences. You create an ``Inotify/Inotify`` actor, add watches for the paths you care about, and iterate over the ``Inotify/Inotify/events`` property to receive ``InotifyEvent`` values as they occur.

```swift
let inotify = try Inotify()
try inotify.addWatch(path: "/tmp/inbox", mask: [.create, .modify])

for await event in await inotify.events {
    print("\(event.mask) at \(event.path)")
}
```

Beyond single-directory watches, the library provides two higher-level methods for monitoring entire directory trees:

- ``Inotify/Inotify/addRecursiveWatch(forDirectory:mask:)`` installs watches on every existing subdirectory at setup time.
- ``Inotify/Inotify/addWatchWithAutomaticSubtreeWatching(forDirectory:mask:)`` does the same **and** automatically watches subdirectories that are created after setup.

You can also exclude certain file or directory names so that they are skipped during directory resolution and silently dropped from the event stream. See ``Inotify/Inotify/exclude(names:)`` and <doc:WatchingDirectoryTrees> for details.

All public types conform to `Sendable`, so they can be safely passed across concurrency boundaries.

## Topics

### Essentials

- ``Inotify/Inotify``
- ``InotifyEvent``
- ``InotifyEventMask``

### Articles

- <doc:WatchingDirectoryTrees>

### Errors

- ``InotifyError``
- ``DirectoryResolverError``

### Low-Level Types

- ``RawInotifyEvent``
