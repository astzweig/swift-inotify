import CInotify
import Testing
@testable import Inotify

@Suite("Event Mask")
struct EventMaskTests {
	@Test(arguments: [
		(InotifyEventMask.access, UInt32(IN_ACCESS)),
		(.attrib, UInt32(IN_ATTRIB)),
		(.closeWrite, UInt32(IN_CLOSE_WRITE)),
		(.closeNoWrite, UInt32(IN_CLOSE_NOWRITE)),
		(.create, UInt32(IN_CREATE)),
		(.delete, UInt32(IN_DELETE)),
		(.deleteSelf, UInt32(IN_DELETE_SELF)),
		(.modify, UInt32(IN_MODIFY)),
		(.moveSelf, UInt32(IN_MOVE_SELF)),
		(.movedFrom, UInt32(IN_MOVED_FROM)),
		(.movedTo, UInt32(IN_MOVED_TO)),
		(.open, UInt32(IN_OPEN)),
		(.dontFollow, UInt32(IN_DONT_FOLLOW)),
		(.onlyDir, UInt32(IN_ONLYDIR)),
		(.oneShot, UInt32(IN_ONESHOT)),
		(.isDir, UInt32(IN_ISDIR)),
		(.ignored, UInt32(IN_IGNORED)),
		(.queueOverflow, UInt32(IN_Q_OVERFLOW)),
		(.unmount, UInt32(IN_UNMOUNT)),
	] as [(InotifyEventMask, UInt32)])
	func matchesTheKernelConstant(mask: InotifyEventMask, constant: UInt32) {
		#expect(mask.rawValue == constant)
	}
}
