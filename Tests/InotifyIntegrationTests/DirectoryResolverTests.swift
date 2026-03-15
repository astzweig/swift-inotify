import Foundation
import Testing
@testable import Inotify

@Suite("Directory Resolver")
struct DirectoryResolverTests {
	@Test func listsDirectoryTree() async throws {
		try await withTempDir { dir in
			let subDirectory = "\(dir)/Subfolder/Folder 01"
			try FileManager.default.createDirectory(atPath: subDirectory, withIntermediateDirectories: true)
			let directories = try await DirectoryResolver.resolve(dir)

			#expect(directories.count == 3)
			#expect(directories.map { $0.description } == [dir, "\(dir)/Subfolder", subDirectory])
		}
	}
}
