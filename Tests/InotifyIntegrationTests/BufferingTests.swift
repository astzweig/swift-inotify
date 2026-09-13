import Foundation
import Testing
@testable import Inotify

@Suite("Event Buffering")
struct BufferingTests {
	@Test func deliversEveryEventOfABurstToALateConsumer() async throws {
		try await withTempDir { dir in
			let fileCount = 1000
			let watcher = try Inotify()
			try await watcher.addWatch(path: dir, mask: .create)

			for index in 0..<fileCount {
				try createFile(at: "\(dir)/file-\(index).txt")
			}
			try await Task.sleep(for: .milliseconds(500))

			let eventTask = Task {
				var events: [InotifyEvent] = []
				for await event in await watcher.events {
					events.append(event)
				}
				return events
			}
			try await Task.sleep(for: .seconds(1))
			eventTask.cancel()
			let events = await eventTask.value

			#expect(events.count == fileCount, "Expected \(fileCount) CREATE events, got \(events.count)")
		}
	}
}
