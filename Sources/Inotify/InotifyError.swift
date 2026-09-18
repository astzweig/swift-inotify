import CInotify

public enum InotifyError: Error, Sendable, Hashable, CustomStringConvertible {
	case initFailed(errno: Int32)
	case addWatchFailed(path: String, errno: Int32)
	case removeWatchFailed(watchDescriptor: Int32, errno: Int32)
	/// The directory could not be listed, so its subdirectories are unknown.
	case listDirectoryFailed(path: String, errno: Int32)

	public var description: String {
		switch self {
		case .initFailed(let code):
			"inotify_init1 failed: \(readableErrno(code))"
		case .addWatchFailed(let path, let code):
			"inotify_add_watch failed for '\(path)': \(readableErrno(code))"
		case .removeWatchFailed(let wd, let code):
			"inotify_rm_watch failed for wd \(wd): \(readableErrno(code))"
		case .listDirectoryFailed(let path, let code):
			"listing '\(path)' failed: \(readableErrno(code))"
		}
	}

	private func readableErrno(_ code: Int32) -> String {
		guard let message = cinotify_error_message(code) else { return "errno \(code)" }
		return String(cString: message) + " (errno \(code))"
	}
}
