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

	/// The direct children of `directory`, without the excluded names.
	static func entries(of directory: FilePath, excluding itemNames: Set<String> = []) async throws -> [(name: String, isDirectory: Bool)] {
		let directoryHandle = try await fileManager.openDirectory(atPath: directory)
		var entries: [(name: String, isDirectory: Bool)] = []
		for try await childContent in directoryHandle.listContents() {
			guard let name = childContent.path.lastComponent?.string else { continue }
			guard !itemNames.contains(name) else { continue }
			entries.append((name: name, isDirectory: childContent.type == .directory))
		}
		try await directoryHandle.close()
		return entries
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
