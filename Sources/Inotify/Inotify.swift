import CInotify

public actor Inotify {
	private let fd: Int32

	public init() throws {
		self.fd = inotify_init1(Int32(IN_NONBLOCK | IN_CLOEXEC))
		guard self.fd >= 0 else {
			throw InotifyError.initFailed(errno: cinotify_get_errno())
		}
	}

	deinit {
		cinotify_deinit(self.fd)
	}
}
