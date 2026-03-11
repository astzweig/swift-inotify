import Testing
import Foundation
@testable import Inotify

@Suite("Watch Management")
struct WatchTests {
	@Test func addWatchReturnsValidDescriptor() async throws {
		try await withTempDir { dir in
			let watcher = try Inotify()
			let wd = try await watcher.addWatch(path: dir, mask: .allEvents)
			#expect(wd >= 0)
		}
	}

	@Test func addWatchOnInvalidPathThrows() async throws {
		let watcher = try Inotify()
		await #expect(throws: InotifyError.self) {
			try await watcher.addWatch(path: "/nonexistent-\(UUID())", mask: .allEvents)
		}
	}

	@Test func removeWatchSucceeds() async throws {
		try await withTempDir { dir in
			let watcher = try Inotify()
			let wd = try await watcher.addWatch(path: dir, mask: .allEvents)
			try await watcher.removeWatch(wd)
		}
	}

	@Test func removeInvalidWatchThrows() async throws {
		let watcher = try Inotify()
		await #expect(throws: InotifyError.self) {
			try await watcher.removeWatch(9999)
		}
	}
}
