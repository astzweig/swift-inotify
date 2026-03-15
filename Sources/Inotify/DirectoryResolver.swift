import _NIOFileSystem

public struct DirectoryResolver {
	static let fileManager = FileSystem.shared

	public static func resolve(_ paths: String..., excluding itemNames: Set<String> = []) async throws -> [FilePath] {
		try await Self.resolve(paths, excluding: itemNames)
	}

	static func resolve(_ paths: [String], excluding itemNames: Set<String> = []) async throws -> [FilePath] {
		var resolved: [FilePath] = []

		for path in paths {
			let path = FilePath(path)
			resolved.append(path)
			try await withSubdirectories(at: path, recursive: true) { subdirectoryPath in
				guard let basename = subdirectoryPath.lastComponent?.description else { return }
				guard !itemNames.contains(basename) else { return }
				resolved.append(subdirectoryPath)
			}
		}

		return resolved
	}

	private static func withSubdirectories(at path: FilePath, recursive: Bool = false, body: (FilePath) async throws -> Void) async throws {
		let directoryHandle = try await fileManager.openDirectory(atPath: path)
		for try await childContent in directoryHandle.listContents() {
			guard childContent.type == .directory else { continue }
			try await body(childContent.path)
			if recursive {
				try await withSubdirectories(at: childContent.path, recursive: recursive, body: body)
			}
		}
		try await directoryHandle.close()
	}
}
