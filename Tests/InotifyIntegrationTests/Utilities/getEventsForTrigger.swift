import Inotify

func getEventsForTrigger(
	in dir: String,
	mask: InotifyEventMask,
	trigger: @escaping (String) async throws -> Void
) async throws -> [InotifyEvent] {
	let watcher = try Inotify()
	try await watcher.addWatch(path: dir, mask: mask)

	let eventTask = Task {
		var events: [InotifyEvent] = []
		for await event in await watcher.events {
			events.append(event)
		}
		return events
	}

	try await Task.sleep(for: .milliseconds(200))
	try await trigger(dir)
	try await Task.sleep(for: .milliseconds(200))

	eventTask.cancel()
	return await eventTask.value
}
