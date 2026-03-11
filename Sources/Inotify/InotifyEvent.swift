import SystemPackage

public struct InotifyEvent: Sendable, Hashable, CustomStringConvertible {
	public let watchDescriptor: Int32
	public let mask: InotifyEventMask
	public let cookie: UInt32
	public let path: FilePath

	public var description: String {
		var parts = ["InotifyEvent(wd: \(watchDescriptor), mask: \(mask), path: \"\(path)\""]
		if cookie != 0 { parts.append("cookie: \(cookie)") }
		return parts.joined(separator: ", ") + ")"
	}
}

extension InotifyEvent {
	public init(from rawEvent: RawInotifyEvent, inDirectory path: String) {
		let dirPath = FilePath(path)
		self.init(
			watchDescriptor: rawEvent.watchDescriptor,
			mask: rawEvent.mask,
			cookie: rawEvent.cookie,
			path: dirPath.appending(rawEvent.name)
		)
	}
}
