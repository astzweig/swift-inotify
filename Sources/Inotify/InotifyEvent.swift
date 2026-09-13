import SystemPackage

/// A filesystem event delivered by an ``Inotify`` instance.
///
/// When the kernel's event queue overflows, it drops events and reports a
/// single event whose ``mask`` contains ``InotifyEventMask/queueOverflow``.
/// Such an event belongs to no watch: its ``watchDescriptor`` is `-1` and
/// its ``path`` is empty. Consumers that must not miss changes should
/// rescan the watched trees when they receive one.
public struct InotifyEvent: Sendable, Hashable, CustomStringConvertible {
	public let watchDescriptor: Int32
	public let mask: InotifyEventMask
	public let cookie: UInt32
	public let path: FilePath
	/// Whether the event was produced by the library for an item that already
	/// existed when its directory became watched, rather than by the kernel.
	public let synthesized: Bool

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
			path: dirPath.appending(rawEvent.name),
			synthesized: rawEvent.synthesized
		)
	}
}
