import Testing
import Foundation
import SystemPackage
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

	/// The limit counts every watch of the user, also those of other
	/// processes, so it leaves room for the one watch of the second instance.
	@Test func releasesTheWatchesOfATreeItCouldNotWatchCompletely() async throws {
		try await withTempDir { dir in
			try await withInotifyWatchLimit(of: 100, for: [.userWatches]) {
				try createSubdirectorytree(at: dir, foldersPerLevel: 4, levels: 4)
				let filepath = "\(dir)/new-file.txt"
				let failedWatcher = try Inotify()
				await #expect(throws: InotifyError.self) {
					try await failedWatcher.addRecursiveWatch(forDirectory: dir, mask: .create)
				}

				let events = try await getEventsForTrigger(in: dir, mask: .create) { _ in
					try createFile(at: filepath, contents: "hello")
				}
				// Deallocating the failed instance would free its watches too, so it
				// must live until the second instance has added its watch.
				withExtendedLifetime(failedWatcher) {}

				let createEvent = events.first { $0.path.string == filepath }
				#expect(createEvent != nil, "Expected a second instance to watch '\(dir)' after the failed one released its watches, got: \(events)")
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

	/// The tree that grows is larger than the limit, so the extension fails
	/// part way; the watches that exist keep working.
	@Test func reportsTheDirectoriesItCannotWatchWhenATreeGrows() async throws {
		try await withTempDir { dir in
			try await withInotifyWatchLimit(of: 100, for: [.userWatches]) {
				let grown = "\(dir)/Grown"
				let filepath = "\(dir)/after-failure.txt"
				let watcher = try Inotify()
				try await watcher.addWatchWithAutomaticSubtreeWatching(forDirectory: dir, mask: [.create])
				try createSubdirectorytree(at: grown, foldersPerLevel: 3, levels: 4)
				let untilFailure = await collectEvents(of: watcher, until: { $0.watchFailure != nil }, timeout: .seconds(5))
				try createFile(at: filepath, contents: "hello")
				let afterFailure = await collectEvents(of: watcher, until: { $0.fileSystemEvent?.path.string == filepath }, timeout: .seconds(5))

				let failure = untilFailure.last?.watchFailure
				#expect(failure?.error == .addWatchFailed(path: failure?.path.string ?? "", errno: ENOSPC), "Expected a watch failure with ENOSPC, got: \(untilFailure.suffix(3))")
				#expect(failure?.path.starts(with: FilePath(grown)) == true, "Expected the failed directory below '\(grown)', got: \(String(describing: failure))")
				#expect(afterFailure.last?.fileSystemEvent?.path.string == filepath, "Expected CREATE for '\(filepath)' after the failure, got: \(afterFailure.suffix(3))")
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
