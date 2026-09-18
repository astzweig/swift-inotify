import Testing
import Foundation
@testable import Inotify

@Suite("Inotify Limits", .serialized)
struct InotifyLimitTests {
	@Test func throwsIfInotifyUpperLimitReached() async throws {
		try await withTempDir { dir in
			try await withInotifyWatchLimit(of: 10) {
				try createSubdirectorytree(at: dir, foldersPerLevel: 4, levels: 3)
				try await Task.sleep(for: .milliseconds(100))

				await #expect(throws: InotifyError.self) {
					let watcher = try Inotify()
					try await watcher.addRecursiveWatch(forDirectory: dir, mask: .allEvents)
				}
			}
		}
	}

	@Test func watchesMassivSubtreesIfAllowed() async throws {
		try await withTempDir { dir in
			try await withInotifyWatchLimit(of: 1000) {
				try createSubdirectorytree(at: dir, foldersPerLevel: 8, levels: 3)
				let subDirectory = "\(dir)/Folder 8/Folder 8/Folder 8"
				let filepath = "\(subDirectory)/new-file.txt"
				try await Task.sleep(for: .milliseconds(100))

				let events = try await getEventsForTrigger(
					in: dir,
					mask: [.create],
					recursive: .recursive
				) { _ in
					assert(FileManager.default.fileExists(atPath: subDirectory))
					try createFile(at: "\(filepath)", contents: "hello")
				}

				let createEvent = events.first { $0.mask.contains(.create) && $0.path.string == filepath }
				#expect(createEvent != nil, "Expected CREATE for '\(filepath)', got: \(events)")
			}
		}
	}

	@Test func reportsQueueOverflowInsteadOfDroppingIt() async throws {
		try await withTempDir { dir in
			try await withInotifyWatchLimit(of: 1, for: [.queuedEvents]) {
				let watcher = try Inotify()
				try await watcher.addWatch(path: dir, mask: .allEvents)
				let overflowTask = Task { () -> (InotifyEvent?, Int) in
					var received = 0
					for await event in await watcher.events {
						received += 1
						if case .queueOverflow = event { return (event, received) }
					}
					return (nil, received)
				}

				let deadline = ContinuousClock.now + .seconds(5)
				var index = 0
				while !overflowTask.isCancelled, ContinuousClock.now < deadline {
					try createFile(at: "\(dir)/burst-\(index).txt", contents: "hello")
					index += 1
					if index % 200 == 0 { await Task.yield() }
				}
				overflowTask.cancel()
				let (overflow, received) = await overflowTask.value

				#expect(overflow == .queueOverflow, "Expected a queue overflow event after \(index) file creations and \(received) received events")
			}
		}
	}
}
