import _NIOFileSystem

public struct DirectoryResolver {
	static let fileManager = FileSystem.shared

	public static func resolve(_ paths: String...) async throws -> [FilePath] {
		try await Self.resolve(paths)
	}

	static func resolve(_ paths: [String]) async throws -> [FilePath] {
		var resolved: [FilePath] = []

		for path in paths {
			let itemPath = FilePath(path)
			try await Self.ensure(itemPath, is: .directory)

			let allDirectoriesIncludingSelf = try await getAllSubdirectoriesAndSelf(at: itemPath)
			resolved.append(contentsOf: allDirectoriesIncludingSelf)
		}

		return resolved
	}

	private static func ensure(_ path: FilePath, is fileType: FileType) async throws {
		guard let fileInfo = try await fileManager.info(forFileAt: path) else {
			throw DirectoryResolverError.pathNotFound(path)
		}

		guard fileInfo.type == fileType else {
			throw DirectoryResolverError.pathIsNoDirectory(path)
		}
	}

	private static func getAllSubdirectoriesAndSelf(at path: FilePath) async throws -> [FilePath] {
		var result: [FilePath] = []
		let directoryHandle = try await fileManager.openDirectory(atPath: path)
		for try await childContent in directoryHandle.listContents(recursive: true) {
			guard childContent.type == .directory else { continue }
			result.append(childContent.path)
		}
		try await directoryHandle.close()
		return result
	}
}
