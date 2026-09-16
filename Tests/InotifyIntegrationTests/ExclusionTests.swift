import Testing
@testable import Inotify

@Suite("Exclusion")
struct ExclusionTests {
	@Test func excludesANameThatMatchesAPattern() async throws {
		let inotify = try Inotify()
		await inotify.exclude(patterns: "*.tmp", "@*")

		#expect(await inotify.isExcluded("scan.tmp"))
		#expect(await inotify.isExcluded("@eaDir"))
		#expect(await !inotify.isExcluded("scan.pdf"))
	}

	@Test func excludesAnExactName() async throws {
		let inotify = try Inotify()
		await inotify.exclude(name: ".git")

		#expect(await inotify.isExcluded(".git"))
		#expect(await !inotify.isExcluded(".gitignore"))
	}
}
