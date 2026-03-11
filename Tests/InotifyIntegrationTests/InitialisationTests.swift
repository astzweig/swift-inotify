import Testing
@testable import Inotify

@Suite("Initialisation")
struct InitTests {
	@Test func createsCleanly() async throws {
		let _ = try Inotify()
	}
}
