import Foundation
import Testing
@testable import Inotify

@Suite("Instance Lifecycle")
struct LifecycleTests {
	@Test func aDeallocatedInstanceDoesNotStealEventsOfItsSuccessor() async throws {
		try await withTempDir { dir in
			let filename = "after-reuse.txt"
			do {
				let predecessor = try Inotify()
				try await predecessor.addWatch(path: dir, mask: .create)
			}

			let events = try await getEventsForTrigger(
				in: dir,
				mask: .create,
			) { try createFile(at: "\($0)/\(filename)") }

			let createEvent = events.first { $0.mask.contains(.create) && $0.path.lastComponent?.string == filename }
			#expect(createEvent != nil, "Expected CREATE for '\(filename)', got: \(events)")
		}
	}
}
