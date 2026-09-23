#if canImport(FoundationEssentials)
	import FoundationEssentials
#else
	import Foundation
#endif
import SystemPackage

public enum DirectoryResolverError: LocalizedError, Equatable {
	case pathNotFound(FilePath)
	case pathIsNoDirectory(FilePath)

	public var errorDescription: String? {
		switch self {
		case .pathNotFound(let path):
			return "Path not found: \(path)"
		case .pathIsNoDirectory(let path):
			return "Path is not a directory: \(path)"
		}
	}
}
