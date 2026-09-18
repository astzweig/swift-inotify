import Foundation
import SystemPackage
import Testing
@testable import Inotify

@Suite("Recursive Event Detection")
struct RecursiveEventTests {
	@Test func detectsFileCreationInSubfolder() async throws {
		try await withTempDir { dir in
			let subDirectory = "\(dir)/Subfolder"
			let filepath = "\(subDirectory)/modify-target.txt"
			try FileManager.default.createDirectory(atPath: subDirectory, withIntermediateDirectories: true)

			let events = try await getEventsForTrigger(
				in: dir,
				mask: [.create],
				recursive: .recursive
			) { _ in try createFile(at: "\(filepath)", contents: "hello") }

			let createEvent = events.first { $0.mask.contains(.create) && $0.path.string == filepath }
			#expect(createEvent != nil, "Expected CREATE for '\(filepath)', got: \(events)")
		}
	}

	@Test func ignoresFileCreationInIgnoredSubfolder() async throws {
		try await withTempDir { dir in
			let subDirectory = "\(dir)/Subfolder"
			let filepath = "\(subDirectory)/modify-target.txt"
			try FileManager.default.createDirectory(atPath: subDirectory, withIntermediateDirectories: true)

			let events = try await getEventsForTrigger(
				in: dir,
				mask: [.create],
				recursive: .recursive,
				exclude: ["Subfolder"]
			) { _ in try createFile(at: "\(filepath)", contents: "hello") }

			let createEvent = events.first { $0.mask.contains(.create) && $0.path.string == filepath }
			#expect(createEvent == nil, "Did not expect CREATE for '\(filepath)', got: \(events)")
		}
	}

	@Test func ignoresFileCreationInASubfolderMatchingAnExcludedPattern() async throws {
		try await withTempDir { dir in
			let subDirectory = "\(dir)/@eaDir"
			let filepath = "\(subDirectory)/modify-target.txt"
			try FileManager.default.createDirectory(atPath: subDirectory, withIntermediateDirectories: true)

			let events = try await getEventsForTrigger(
				in: dir,
				mask: [.create],
				recursive: .recursive,
				excludePatterns: ["@*"]
			) { _ in try createFile(at: "\(filepath)", contents: "hello") }

			let createEvent = events.first { $0.mask.contains(.create) && $0.path.string == filepath }
			#expect(createEvent == nil, "Did not expect CREATE for '\(filepath)', got: \(events)")
		}
	}

	@Test func doesNotWatchANewSubfolderMatchingAnExcludedPattern() async throws {
		try await withTempDir { dir in
			let subDirectory = "\(dir)/@eaDir"
			let filepath = "\(subDirectory)/modify-target.txt"

			let events = try await getEventsForTrigger(
				in: dir,
				mask: [.create],
				recursive: .withAutomaticSubtreeWatching,
				excludePatterns: ["@*"]
			) { _ in
				try FileManager.default.createDirectory(atPath: subDirectory, withIntermediateDirectories: true)
				try await Task.sleep(for: .milliseconds(400))
				try createFile(at: "\(filepath)", contents: "hello")
			}

			#expect(events.isEmpty, "Did not expect any event, got: \(events)")
		}
	}

	@Test func newSubfoldersOfRecursiveWatchAreAutomaticallyWatchedToo() async throws {
		try await withTempDir { dir in
			let subDirectory = "\(dir)/Subfolder"
			let filepath = "\(subDirectory)/modify-target.txt"

			let events = try await getEventsForTrigger(
				in: dir,
				mask: [.create],
				recursive: .withAutomaticSubtreeWatching
			) { _ in
				try FileManager.default.createDirectory(atPath: subDirectory, withIntermediateDirectories: true)
				try await Task.sleep(for: .milliseconds(400))
				try createFile(at: "\(filepath)", contents: "hello")
			}

			let createEvent = events.first { $0.mask.contains(.create) && $0.path.string == filepath }
			#expect(createEvent != nil, "Expected CREATE for '\(filepath)', got: \(events)")
		}
	}

	@Test func stopsReportingForDirectoriesMovedOutOfTheWatchedTree() async throws {
		try await withTempDir { dir in
			let root = "\(dir)/Root"
			let outside = "\(dir)/Outside"
			let movedSource = "\(root)/Moved"
			let movedDestination = "\(outside)/Moved"
			let filename = "created-after-move.txt"
			try FileManager.default.createDirectory(atPath: movedSource, withIntermediateDirectories: true)
			try FileManager.default.createDirectory(atPath: outside, withIntermediateDirectories: true)

			let events = try await getEventsForTrigger(
				in: root,
				mask: [.create, .movedFrom],
				recursive: .withAutomaticSubtreeWatching
			) { _ in
				try FileManager.default.moveItem(atPath: movedSource, toPath: movedDestination)
				try await Task.sleep(for: .milliseconds(400))
				try createFile(at: "\(movedDestination)/\(filename)", contents: "hello")
			}

			let staleEvent = events.first { $0.mask.contains(.create) && $0.path.lastComponent?.string == filename }
			#expect(staleEvent == nil, "Did not expect CREATE for '\(filename)' after its directory left the tree, got: \(events)")
		}
	}

	@Test func watchesAndReportsContentOfDirectoriesMovedIntoTheTree() async throws {
		try await withTempDir { dir in
			let root = "\(dir)/Root"
			let treeSource = "\(dir)/Outside/Tree"
			let treeDestination = "\(root)/Tree"
			try FileManager.default.createDirectory(atPath: "\(treeSource)/Sub", withIntermediateDirectories: true)
			try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
			try createFile(at: "\(treeSource)/existing.txt", contents: "hello")
			try createFile(at: "\(treeSource)/Sub/nested.txt", contents: "hello")

			let events = try await getEventsForTrigger(
				in: root,
				mask: [.create, .movedTo],
				recursive: .withAutomaticSubtreeWatching
			) { _ in
				try FileManager.default.moveItem(atPath: treeSource, toPath: treeDestination)
				try await Task.sleep(for: .milliseconds(400))
				try createFile(at: "\(treeDestination)/Sub/created-after-move.txt", contents: "hello")
			}

			let movedIn = events.first { $0.mask.contains(.movedTo) && $0.mask.contains(.isDir) && $0.path.string == treeDestination }
			#expect(movedIn != nil, "Expected MOVED_TO for '\(treeDestination)', got: \(events)")

			let existing = events.first { $0.synthesized && $0.mask.contains(.movedTo) && $0.path.string == "\(treeDestination)/existing.txt" }
			#expect(existing != nil, "Expected a synthesized MOVED_TO for the existing file, got: \(events)")

			let subdirectory = events.first { $0.synthesized && $0.mask.contains(.isDir) && $0.path.string == "\(treeDestination)/Sub" }
			#expect(subdirectory != nil, "Expected a synthesized MOVED_TO for the existing subdirectory, got: \(events)")

			let nested = events.first { $0.synthesized && $0.path.string == "\(treeDestination)/Sub/nested.txt" }
			#expect(nested != nil, "Expected a synthesized MOVED_TO for the nested file, got: \(events)")

			let createdAfterMove = events.first { !$0.synthesized && $0.mask.contains(.create) && $0.path.string == "\(treeDestination)/Sub/created-after-move.txt" }
			#expect(createdAfterMove != nil, "Expected CREATE inside the moved-in subdirectory, got: \(events)")
		}
	}

	/// Needs a process that directory permissions apply to; the test runner
	/// drops root's override capabilities for that.
	@Test func reportsANewDirectoryItCannotReadAndWatchesItsSiblings() async throws {
		try await withTempDir { dir in
			let root = "\(dir)/Root"
			let treeSource = "\(dir)/Outside/Grown"
			let treeDestination = "\(root)/Grown"
			let locked = "\(treeDestination)/Locked"
			let filepath = "\(treeDestination)/Open/created.txt"
			try FileManager.default.createDirectory(atPath: "\(treeSource)/Locked", withIntermediateDirectories: true)
			try FileManager.default.createDirectory(atPath: "\(treeSource)/Open", withIntermediateDirectories: true)
			try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
			try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: "\(treeSource)/Locked")
			defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked) }

			let events = try await getInotifyEventsForTrigger(
				in: root,
				mask: [.create, .movedTo],
				recursive: .withAutomaticSubtreeWatching
			) { _ in
				try FileManager.default.moveItem(atPath: treeSource, toPath: treeDestination)
				try await Task.sleep(for: .milliseconds(400))
				try createFile(at: filepath, contents: "hello")
			}

			let failures = events.compactMap(\.watchFailure)
			#expect(failures.count == 1, "Expected exactly the locked directory to be reported, got: \(events)")
			#expect(failures.first?.path == FilePath(locked))
			#expect(failures.first?.error == .listDirectoryFailed(path: locked, errno: EACCES))
			let sibling = events.compactMap(\.fileSystemEvent).first { !$0.synthesized && $0.mask.contains(.create) && $0.path.string == filepath }
			#expect(sibling != nil, "Expected CREATE inside the readable sibling, got: \(events)")
		}
	}

	/// Events are transformed as they are consumed, so a directory that is
	/// created and removed before consumption starts is gone when the
	/// library tries to watch it.
	@Test func doesNotReportADirectoryThatVanishedBeforeItCouldBeWatched() async throws {
		try await withTempDir { dir in
			let vanished = "\(dir)/Vanished"
			let watcher = try Inotify()
			try await watcher.addWatchWithAutomaticSubtreeWatching(forDirectory: dir, mask: [.create])
			try FileManager.default.createDirectory(atPath: vanished, withIntermediateDirectories: false)
			try FileManager.default.removeItem(atPath: vanished)

			let events = await collectEvents(of: watcher, for: .milliseconds(500))

			#expect(events.compactMap(\.watchFailure).isEmpty, "Did not expect a watch failure for a vanished directory, got: \(events)")
			let created = events.compactMap(\.fileSystemEvent).first { $0.mask.contains(.create) && $0.path.string == vanished }
			#expect(created != nil, "Expected CREATE for '\(vanished)', got: \(events)")
		}
	}
}
