import CInotify
import _NIOFileSystem

public struct DirectoryResolver {
	static let fileManager = FileSystem.shared

	public static func resolve(_ paths: String..., excluding itemNames: Set<String> = []) async throws -> [FilePath] {
		try await Self.resolve(paths, excluding: ExclusionList(names: itemNames))
	}

	static func resolve(_ paths: [String], excluding exclusions: ExclusionList = ExclusionList()) async throws -> [FilePath] {
		var resolved: [FilePath] = []

		for path in paths {
			let path = FilePath(path)
			resolved.append(path)
			try await withSubdirectories(at: path, excluding: exclusions) { resolved.append($0) }
		}

		return resolved
	}

	/// Resolves `path` like ``resolve(_:excluding:)``, but a directory that
	/// cannot be listed is recorded with its errno and skipped together with
	/// its subtree, instead of failing the whole resolution.
	static func resolveTolerantly(_ path: FilePath, excluding exclusions: ExclusionList) async -> TolerantResolution {
		var resolution = TolerantResolution()
		await collectDirectories(at: path, excluding: exclusions, into: &resolution)
		return resolution
	}

	private static func collectDirectories(at path: FilePath, excluding exclusions: ExclusionList, into resolution: inout TolerantResolution) async {
		let subdirectories: [FilePath]
		do {
			subdirectories = try await entries(of: path, excluding: exclusions)
				.filter(\.isDirectory)
				.map { path.appending($0.name) }
		} catch {
			resolution.unreadable.append((path: path, errno: errno(of: error)))
			return
		}
		resolution.directories.append(path)
		for subdirectory in subdirectories {
			await collectDirectories(at: subdirectory, excluding: exclusions, into: &resolution)
		}
	}

	/// The errno behind a file system error; the error's code when the
	/// system call is unknown.
	private static func errno(of error: any Error) -> Int32 {
		guard let fileSystemError = error as? FileSystemError else { return EIO }
		if let systemCall = fileSystemError.cause as? FileSystemError.SystemCallError {
			return systemCall.errno.rawValue
		}
		return switch fileSystemError.code {
		case .permissionDenied: EACCES
		case .notFound: ENOENT
		default: EIO
		}
	}

	/// The direct children of `directory`, without the excluded items.
	static func entries(of directory: FilePath, excluding exclusions: ExclusionList = ExclusionList()) async throws -> [(name: String, isDirectory: Bool)] {
		let directoryHandle = try await fileManager.openDirectory(atPath: directory)
		var entries: [(name: String, isDirectory: Bool)] = []
		for try await childContent in directoryHandle.listContents() {
			guard let name = childContent.path.lastComponent?.string else { continue }
			guard !exclusions.excludes(name) else { continue }
			entries.append((name: name, isDirectory: childContent.type == .directory))
		}
		try await directoryHandle.close()
		return entries
	}

	/// Calls `body` for every subdirectory below `path`, depth first. Excluded
	/// directories are neither reported nor descended into.
	private static func withSubdirectories(at path: FilePath, excluding exclusions: ExclusionList, body: (FilePath) async throws -> Void) async throws {
		let directoryHandle = try await fileManager.openDirectory(atPath: path)
		for try await childContent in directoryHandle.listContents() {
			guard childContent.type == .directory else { continue }
			guard let name = childContent.path.lastComponent?.string, !exclusions.excludes(name) else { continue }
			try await body(childContent.path)
			try await withSubdirectories(at: childContent.path, excluding: exclusions, body: body)
		}
		try await directoryHandle.close()
	}
}

struct TolerantResolution {
	/// The directories that could be listed, each before its subdirectories.
	var directories: [FilePath] = []
	var unreadable: [(path: FilePath, errno: Int32)] = []
}
