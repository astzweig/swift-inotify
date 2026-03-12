import Inotify

enum RecursivKind {
	case nonrecursive
	case recursive
	case withAutomaticSubtreeWatching
}

func getEventsForTrigger(
	in dir: String,
	mask: InotifyEventMask,
	recursive: RecursivKind = .nonrecursive,
	trigger: @escaping (String) async throws -> Void,
) async throws -> [InotifyEvent] {
	let watcher = try Inotify()
	switch recursive {
	case .nonrecursive:
		try await watcher.addWatch(path: dir, mask: mask)
	case .recursive:
		try await watcher.addRecursiveWatch(forDirectory: dir, mask: mask)
	case .withAutomaticSubtreeWatching:
		try await watcher.addWatchWithAutomaticSubtreeWatching(forDirectory: dir, mask: mask)
	}

	let eventTask = Task {
		var events: [InotifyEvent] = []
		for await event in await watcher.events {
			events.append(event)
		}
		return events
	}

	try await Task.sleep(for: .milliseconds(100))
	try await trigger(dir)
	try await Task.sleep(for: .milliseconds(500))

	eventTask.cancel()
	return await eventTask.value
}
