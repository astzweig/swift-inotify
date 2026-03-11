import CInotify

public enum InotifyError: Error, Sendable, CustomStringConvertible {
	case initFailed(errno: Int32)

	public var description: String {
		switch self {
		case .initFailed(let code):
			"inotify_init1 failed: \(readableErrno(code))"
		}
	}

	private func readableErrno(_ code: Int32) -> String {
		if let cStr = get_error_message() {
			return String(cString: cStr) + " (errno \(code))"
		}
		return "errno \(code)"
	}
}
