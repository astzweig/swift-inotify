import CInotify

struct InotifyEventParser {
	static let readBufferSize = 4096

	static func parse(fromFileDescriptor fd: Int32) -> [RawInotifyEvent] {
		let buffer = UnsafeMutableRawPointer.allocate(
			byteCount: Self.readBufferSize,
			alignment: MemoryLayout<inotify_event>.alignment
		)
		defer { buffer.deallocate() }

		let bytesRead = read(fd, buffer, readBufferSize)
		guard bytesRead > 0 else { return [] }

		return Self.parseEventBuffer(buffer, bytesRead: bytesRead)
	}

	private static func parseEventBuffer(
		_ buffer: UnsafeMutableRawPointer,
		bytesRead: Int
	) -> [RawInotifyEvent] {
		var events: [RawInotifyEvent] = []
		var offset = 0

		while offset < bytesRead {
			let eventPointer = buffer.advanced(by: offset)
			let rawEvent = eventPointer.assumingMemoryBound(to: inotify_event.self).pointee

			events.append(RawInotifyEvent(
				watchDescriptor: rawEvent.wd,
				mask: InotifyEventMask(rawValue: rawEvent.mask),
				cookie: rawEvent.cookie,
				name: Self.extractName(from: eventPointer, nameLength: rawEvent.len)
			))

			offset += Self.eventSize(nameLength: rawEvent.len)
		}

		return events
	}

	private static func extractName(
		from eventPointer: UnsafeMutableRawPointer,
		nameLength: UInt32
	) -> String {
		guard nameLength > 0 else { return "" }
		let namePointer = eventPointer
			.advanced(by: MemoryLayout<inotify_event>.size)
			.assumingMemoryBound(to: CChar.self)
		return String(cString: namePointer)
	}

	private static func eventSize(nameLength: UInt32) -> Int {
		MemoryLayout<inotify_event>.size + Int(nameLength)
	}
}
