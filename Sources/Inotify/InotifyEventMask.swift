import CInotify

public struct InotifyEventMask: OptionSet, Sendable, Hashable {
	public let rawValue: UInt32

	public init(rawValue: UInt32) {
		self.rawValue = rawValue
	}

	// MARK: - Watchable Events

	public static let access        = InotifyEventMask(rawValue: UInt32(IN_ACCESS))
	public static let attrib        = InotifyEventMask(rawValue: UInt32(IN_ATTRIB))
	public static let closeWrite    = InotifyEventMask(rawValue: UInt32(IN_CLOSE_WRITE))
	public static let closeNoWrite  = InotifyEventMask(rawValue: UInt32(IN_CLOSE_NOWRITE))
	public static let create        = InotifyEventMask(rawValue: UInt32(IN_CREATE))
	public static let delete        = InotifyEventMask(rawValue: UInt32(IN_DELETE))
	public static let deleteSelf    = InotifyEventMask(rawValue: UInt32(IN_DELETE_SELF))
	public static let modify        = InotifyEventMask(rawValue: UInt32(IN_MODIFY))
	public static let moveSelf      = InotifyEventMask(rawValue: UInt32(IN_MOVE_SELF))
	public static let movedFrom     = InotifyEventMask(rawValue: UInt32(IN_MOVED_FROM))
	public static let movedTo       = InotifyEventMask(rawValue: UInt32(IN_MOVED_TO))
	public static let open          = InotifyEventMask(rawValue: UInt32(IN_OPEN))

	// MARK: - Combinations

	public static let move: InotifyEventMask = [.movedFrom, .movedTo]
	public static let close: InotifyEventMask = [.closeWrite, .closeNoWrite]
	public static let allEvents: InotifyEventMask = [
		.access, .attrib, .closeWrite, .closeNoWrite,
		.create, .delete, .deleteSelf, .modify,
		.moveSelf, .movedFrom, .movedTo, .open
	]

	// MARK: - Watch Flags

	public static let dontFollow    = InotifyEventMask(rawValue: UInt32(IN_DONT_FOLLOW))
	public static let onlyDir       = InotifyEventMask(rawValue: UInt32(IN_ONLYDIR))
	public static let oneShot       = InotifyEventMask(rawValue: UInt32(IN_ONESHOT))

	// MARK: - Kernel-Only Flags

	public static let isDir         = InotifyEventMask(rawValue: UInt32(IN_ISDIR))
	public static let ignored       = InotifyEventMask(rawValue: UInt32(IN_IGNORED))
	public static let queueOverflow = InotifyEventMask(rawValue: UInt32(IN_Q_OVERFLOW))
	public static let unmount       = InotifyEventMask(rawValue: UInt32(IN_UNMOUNT))
}
