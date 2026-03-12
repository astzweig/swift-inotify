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
}
