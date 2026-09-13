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
			try await withSubdirectories(at: path, excluding: itemNames) { resolved.append($0) }
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

	/// Calls `body` for every subdirectory below `path`, depth first. Excluded
	/// names are neither reported nor descended into.
	private static func withSubdirectories(at path: FilePath, excluding itemNames: Set<String>, body: (FilePath) async throws -> Void) async throws {
		let directoryHandle = try await fileManager.openDirectory(atPath: path)
		for try await childContent in directoryHandle.listContents() {
			guard childContent.type == .directory else { continue }
			guard let name = childContent.path.lastComponent?.string, !itemNames.contains(name) else { continue }
			try await body(childContent.path)
			try await withSubdirectories(at: childContent.path, excluding: itemNames, body: body)
		}
		try await directoryHandle.close()
	}
}
