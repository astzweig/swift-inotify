import Foundation
import Testing
@testable import Inotify

@Suite("File Event Detection")
struct EventTests {
	@Test func detectsFileCreation() async throws {
		try await withTempDir { dir in
			let filename = "testfile.txt"
			let events = try await getEventsForTrigger(
				in: dir,
				mask: [.create, .closeWrite],
			) { try createFile(at: "\($0)/\(filename)", contents: "hello") }

			let createEvent = events.first { $0.mask.contains(.create) && $0.path.lastComponent?.string == filename }
			#expect(createEvent != nil, "Expected CREATE for '\(filename)', got: \(events)")
		}
	}

	@Test func detectsFileModification() async throws {
		try await withTempDir { dir in
			let filepath = "\(dir)/modify-target.txt"
			try createFile(at: filepath)

			let events = try await getEventsForTrigger(
				in: dir,
				mask: .modify,
			) { _ in try "hello".write(toFile: filepath, atomically: false, encoding: .utf8) }

			let modifyEvent = events.first { $0.mask.contains(.modify) && $0.path.string == filepath }
			#expect(modifyEvent != nil, "Expected MODIFY for '\(filepath)', got: \(events)")
		}
	}

	@Test func detectsFileDeletion() async throws {
		try await withTempDir { dir in
			let filepath = "\(dir)/delete-me.txt"
			try createFile(at: filepath)

			let events = try await getEventsForTrigger(
				in: dir,
				mask: .delete,
			) { _ in try FileManager.default.removeItem(atPath: filepath) }

			let deleteEvent = events.first { $0.mask.contains(.delete) && $0.path.string == filepath }
			#expect(deleteEvent != nil, "Expected DELETE for '\(filepath)', got: \(events)")
		}
	}

	@Test func detectsSubdirectoryCreationWithIsDirFlag() async throws {
		try await withTempDir { dir in
			let folderpath = "\(dir)/subdir-\(UUID())"

			let events = try await getEventsForTrigger(
				in: dir,
				mask: .create,
			) { _ in try FileManager.default.createDirectory(atPath: folderpath, withIntermediateDirectories: false) }

			let createEvent = events.first { $0.mask.contains(.create) && $0.mask.contains(.isDir) && $0.path.string == folderpath }
			#expect(createEvent != nil, "Expected CREATE for folder '\(folderpath)', got: \(events)")
		}
	}

	@Test func detectsMoveWithMatchingCookies() async throws {
		try await withTempDir { dir in
			let sourceFilePath = "\(dir)/move-src.txt"
			let destionationFilePath = "\(dir)/move-dst.txt"
			try createFile(at: sourceFilePath)

			let events = try await getEventsForTrigger(
				in: dir,
				mask: .move,
			) { _ in try FileManager.default.moveItem(atPath: sourceFilePath, toPath: destionationFilePath) }

			let movedFromEvent = events.first { $0.mask.contains(.movedFrom) && $0.path.string == sourceFilePath }
			#expect(movedFromEvent != nil, "Expected MOVED_FROM for '\(movedFromEvent)', got: \(events)")

			let movedToEvent = events.first { $0.mask.contains(.movedTo) && $0.path.string == destionationFilePath }
			#expect(movedToEvent != nil, "Expected MOVED_TO for '\(destionationFilePath)', got: \(events)")
			#expect(movedFromEvent?.cookie == movedToEvent?.cookie)
		}
	}

	@Test func eventsArriveInOrder() async throws {
		try await withTempDir { dir in
			let filepath = "\(dir)/ordered-test.txt"

			let events = try await getEventsForTrigger(in: dir, mask: [.create, .delete]) { _ in
				try createFile(at: filepath)
				try await Task.sleep(for: .milliseconds(50))
				try FileManager.default.removeItem(atPath: filepath)
			}

			let createIdx = events.firstIndex { $0.mask.contains(.create) && $0.path.string == filepath }
			#expect(createIdx != nil)

			let deleteIdx = events.firstIndex { $0.mask.contains(.delete) && $0.path.string == filepath }
			#expect(deleteIdx != nil)

			if let createIdx, let deleteIdx {
				#expect(createIdx < deleteIdx)
			}
		}
	}

	@Test func maskFiltersCorrectly() async throws {
		try await withTempDir { dir in
			let filepath = "\(dir)/mask-filter.txt"

			let events = try await getEventsForTrigger(in: dir, mask: .delete) { _ in
				try createFile(at: filepath)
			}

			let deleteEvent = events.first { $0.mask.contains(.delete) && $0.path.string == filepath }
			#expect(deleteEvent == nil)
		}
	}
}
