import CInotify

public actor Inotify {
	private let fd: Int32
	private var watches: [Int32: String] = [:]

	public init() throws {
		self.fd = inotify_init1(Int32(IN_NONBLOCK | IN_CLOEXEC))
		guard self.fd >= 0 else {
			throw InotifyError.initFailed(errno: cinotify_get_errno())
		}
	}

	@discardableResult
	public func addWatch(path: String, mask: InotifyEventMask) throws -> Int32 {
		let wd = inotify_add_watch(self.fd, path, mask.rawValue)
		guard wd >= 0 else {
			throw InotifyError.addWatchFailed(path: path, errno: cinotify_get_errno())
		}
		watches[wd] = path
		return wd
	}

	deinit {
		cinotify_deinit(self.fd)
	}
}
