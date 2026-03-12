import _NIOFileSystem

public struct DoccFinder {
	static let fileManager = FileSystem.shared

	public static func getTargetsWithDocumentation(at paths: String...) async throws -> [String] {
		try await Self.getTargetsWithDocumentation(at: paths)
	}

	static func getTargetsWithDocumentation(at paths: [String]) async throws -> [String] {
		var resolved: [String] = []

		for path in paths {
			let itemPath = FilePath(path)

			try await withSubdirectories(at: itemPath) { targetPath in
				print("Target path is", targetPath.description)
				try await withSubdirectories(at: targetPath) { subdirectory in
					guard subdirectory.description.hasSuffix(".docc") else { return }
					guard let target = targetPath.lastComponent?.description else { return }
					resolved.append(target)
				}
			}
		}

		return resolved
	}

	private static func withSubdirectories(at path: FilePath, body: (FilePath) async throws -> Void) async throws {
		let directoryHandle = try await fileManager.openDirectory(atPath: path)
		for try await childContent in directoryHandle.listContents() {
			guard childContent.type == .directory else { continue }
			try await body(childContent.path)
		}
		try await directoryHandle.close()
	}
}
