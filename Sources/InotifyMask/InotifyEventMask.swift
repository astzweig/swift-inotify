/// The events and flags of an inotify watch or event, as bits.
///
/// The values are the constants of the Linux `<sys/inotify.h>` header,
/// which are part of the kernel's stable interface. Spelling them out here
/// keeps this module free of the C header, so it builds on every platform
/// and lets code that only stores or compares masks be tested off Linux.
public struct InotifyEventMask: OptionSet, Sendable, Hashable {
	public let rawValue: UInt32

	public init(rawValue: UInt32) {
		self.rawValue = rawValue
	}

	// MARK: - Watchable Events

	public static let access = InotifyEventMask(rawValue: 0x0000_0001)
	public static let modify = InotifyEventMask(rawValue: 0x0000_0002)
	public static let attrib = InotifyEventMask(rawValue: 0x0000_0004)
	public static let closeWrite = InotifyEventMask(rawValue: 0x0000_0008)
	public static let closeNoWrite = InotifyEventMask(rawValue: 0x0000_0010)
	public static let open = InotifyEventMask(rawValue: 0x0000_0020)
	public static let movedFrom = InotifyEventMask(rawValue: 0x0000_0040)
	public static let movedTo = InotifyEventMask(rawValue: 0x0000_0080)
	public static let create = InotifyEventMask(rawValue: 0x0000_0100)
	public static let delete = InotifyEventMask(rawValue: 0x0000_0200)
	public static let deleteSelf = InotifyEventMask(rawValue: 0x0000_0400)
	public static let moveSelf = InotifyEventMask(rawValue: 0x0000_0800)

	// MARK: - Combinations

	public static let move: InotifyEventMask = [.movedFrom, .movedTo]
	public static let close: InotifyEventMask = [.closeWrite, .closeNoWrite]
	public static let allEvents: InotifyEventMask = [
		.access, .attrib, .closeWrite, .closeNoWrite,
		.create, .delete, .deleteSelf, .modify,
		.moveSelf, .movedFrom, .movedTo, .open,
	]

	// MARK: - Watch Flags

	public static let onlyDir = InotifyEventMask(rawValue: 0x0100_0000)
	public static let dontFollow = InotifyEventMask(rawValue: 0x0200_0000)
	public static let oneShot = InotifyEventMask(rawValue: 0x8000_0000)

	// MARK: - Kernel-Only Flags

	public static let unmount = InotifyEventMask(rawValue: 0x0000_2000)
	public static let queueOverflow = InotifyEventMask(rawValue: 0x0000_4000)
	public static let ignored = InotifyEventMask(rawValue: 0x0000_8000)
	public static let isDir = InotifyEventMask(rawValue: 0x4000_0000)
}
