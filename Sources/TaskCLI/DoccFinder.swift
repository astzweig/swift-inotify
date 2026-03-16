import _NIOFileSystem

public struct DoccFinder {
	static let fileManager = FileSystem.shared

	public static func hasDoccFolder(at path: String) async throws -> Bool {
		let itemPath = FilePath(path)
		var hasDoccFolder = false

		try await withSubdirectories(at: itemPath) { subdirectory in
			guard subdirectory.description.hasSuffix(".docc") else { return }
			hasDoccFolder = true
		}
		return hasDoccFolder
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
