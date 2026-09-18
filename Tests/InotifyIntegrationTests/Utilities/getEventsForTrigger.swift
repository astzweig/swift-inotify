import Inotify
import SystemPackage

enum RecursivKind {
	case nonrecursive
	case recursive
	case withAutomaticSubtreeWatching
}

/// The file system events an instance delivers around `trigger`.
func getEventsForTrigger(
	in dir: String,
	mask: InotifyEventMask,
	recursive: RecursivKind = .nonrecursive,
	exclude: [String] = [],
	excludePatterns: [String] = [],
	trigger: @escaping (String) async throws -> Void,
) async throws -> [FileSystemEvent] {
	let events = try await getInotifyEventsForTrigger(
		in: dir,
		mask: mask,
		recursive: recursive,
		exclude: exclude,
		excludePatterns: excludePatterns,
		trigger: trigger
	)
	return events.compactMap(\.fileSystemEvent)
}

/// Everything an instance delivers around `trigger`, including the
/// events that are not about a file system item.
func getInotifyEventsForTrigger(
	in dir: String,
	mask: InotifyEventMask,
	recursive: RecursivKind = .nonrecursive,
	exclude: [String] = [],
	excludePatterns: [String] = [],
	trigger: @escaping (String) async throws -> Void,
) async throws -> [InotifyEvent] {
	let watcher = try Inotify()
	await watcher.exclude(names: exclude)
	await watcher.exclude(patterns: excludePatterns)
	switch recursive {
	case .nonrecursive:
		try await watcher.addWatch(path: dir, mask: mask)
	case .recursive:
		try await watcher.addRecursiveWatch(forDirectory: dir, mask: mask)
	case .withAutomaticSubtreeWatching:
		try await watcher.addWatchWithAutomaticSubtreeWatching(forDirectory: dir, mask: mask)
	}

	let eventTask = Task { await collectEvents(of: watcher) }

	try await Task.sleep(for: .milliseconds(100))
	try await trigger(dir)
	try await Task.sleep(for: .milliseconds(500))

	eventTask.cancel()
	return await eventTask.value
}

/// Everything `watcher` delivers until the current task is cancelled.
func collectEvents(of watcher: Inotify) async -> [InotifyEvent] {
	var events: [InotifyEvent] = []
	for await event in await watcher.events {
		events.append(event)
	}
	return events
}

/// Everything `watcher` delivers up to and including the first event that
/// satisfies `predicate`, or until `timeout` passes.
func collectEvents(
	of watcher: Inotify,
	until predicate: @escaping @Sendable (InotifyEvent) -> Bool,
	timeout: Duration
) async -> [InotifyEvent] {
	let eventTask = Task { () -> [InotifyEvent] in
		var events: [InotifyEvent] = []
		for await event in await watcher.events {
			events.append(event)
			if predicate(event) { break }
		}
		return events
	}
	let timeoutTask = Task {
		try? await Task.sleep(for: timeout)
		eventTask.cancel()
	}
	defer { timeoutTask.cancel() }
	return await eventTask.value
}

/// Everything `watcher` delivers within `duration`.
func collectEvents(of watcher: Inotify, for duration: Duration) async -> [InotifyEvent] {
	let eventTask = Task { await collectEvents(of: watcher) }
	try? await Task.sleep(for: duration)
	eventTask.cancel()
	return await eventTask.value
}

extension InotifyEvent {
	var fileSystemEvent: FileSystemEvent? {
		if case .fileSystem(let event) = self { return event }
		return nil
	}

	var watchFailure: (path: FilePath, error: InotifyError)? {
		if case .watchFailed(let path, let error) = self { return (path, error) }
		return nil
	}
}
