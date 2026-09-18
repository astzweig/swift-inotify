import Testing
@testable import Inotify

@Suite("Error Description")
struct InotifyErrorTests {
	@Test func describesTheStoredErrnoAndNotTheCurrentOne() {
		let error = InotifyError.addWatchFailed(path: "/watched", errno: 28)

		#expect(error.description == "inotify_add_watch failed for '/watched': No space left on device (errno 28)")
	}
}
