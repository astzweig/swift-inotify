import SystemPackage

/// A change to a watched file or directory, as delivered by an ``Inotify``
/// instance inside ``InotifyEvent/fileSystem(_:)``.
public struct FileSystemEvent: Sendable, Hashable, CustomStringConvertible {
	public let watchDescriptor: Int32
	public let mask: InotifyEventMask
	public let cookie: UInt32
	public let path: FilePath
	/// Whether the event was produced by the library for an item that already
	/// existed when its directory became watched, rather than by the kernel.
	public let synthesized: Bool

	public var description: String {
		var parts = ["FileSystemEvent(wd: \(watchDescriptor), mask: \(mask), path: \"\(path)\""]
		if cookie != 0 { parts.append("cookie: \(cookie)") }
		return parts.joined(separator: ", ") + ")"
	}
}

extension FileSystemEvent {
	public init(from rawEvent: RawInotifyEvent, inDirectory path: String) {
		let dirPath = FilePath(path)
		self.init(
			watchDescriptor: rawEvent.watchDescriptor,
			mask: rawEvent.mask,
			cookie: rawEvent.cookie,
			path: dirPath.appending(rawEvent.name),
			synthesized: rawEvent.synthesized
		)
	}
}
