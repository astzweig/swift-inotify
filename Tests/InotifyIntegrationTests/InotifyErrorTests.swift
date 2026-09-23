import Foundation
import SystemPackage
import Testing
@testable import Inotify

@Suite("Error Description")
struct InotifyErrorTests {
	@Test func describesTheStoredErrnoAndNotTheCurrentOne() {
		let error = InotifyError.addWatchFailed(path: "/watched", errno: 28)

		#expect(error.description == "inotify_add_watch failed for '/watched': No space left on device (errno 28)")
	}

	@Test(arguments: [
		(DirectoryResolverError.pathNotFound("/missing"), "Path not found: /missing"),
		(DirectoryResolverError.pathIsNoDirectory("/file"), "Path is not a directory: /file"),
	])
	func describesAResolverErrorAsALocalizedError(error: DirectoryResolverError, text: String) {
		let localized: any LocalizedError = error

		#expect(localized.errorDescription == text)
	}
}
