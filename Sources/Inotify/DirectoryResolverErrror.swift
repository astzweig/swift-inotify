import Foundation
import SystemPackage

public enum DirectoryResolverError: LocalizedError, Equatable {
	case pathNotFound(FilePath)
	case pathIsNoDirectory(FilePath)

	var errorDescription: String {
		switch self {
		case .pathNotFound(let path):
			return "Path not found: \(path)"
		case .pathIsNoDirectory(let path):
			return "Path is not a directory: \(path)"
		}
	}
}
