import CInotify

public enum InotifyError: Error, Sendable, CustomStringConvertible {
	case initFailed(errno: Int32)
	case addWatchFailed(path: String, errno: Int32)
	case removeWatchFailed(watchDescriptor: Int32, errno: Int32)

	public var description: String {
		switch self {
		case .initFailed(let code):
			"inotify_init1 failed: \(readableErrno(code))"
		case .addWatchFailed(let path, let code):
			"inotify_add_watch failed for '\(path)': \(readableErrno(code))"
		case .removeWatchFailed(let wd, let code):
			"inotify_rm_watch failed for wd \(wd): \(readableErrno(code))"
		}
	}

	private func readableErrno(_ code: Int32) -> String {
		if let cStr = get_error_message() {
			return String(cString: cStr) + " (errno \(code))"
		}
		return "errno \(code)"
	}
}
