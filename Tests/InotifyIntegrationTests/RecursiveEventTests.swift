import Foundation
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
				recursive: true
			) { _ in try createFile(at: "\(filepath)", contents: "hello") }

			let createEvent = events.first { $0.mask.contains(.create) && $0.path.string == filepath }
			#expect(createEvent != nil, "Expected CREATE for '\(filepath)', got: \(events)")
		}
	}
}
