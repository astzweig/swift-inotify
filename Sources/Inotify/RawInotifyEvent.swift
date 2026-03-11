public struct RawInotifyEvent: Sendable, Hashable, CustomStringConvertible {
	public let watchDescriptor: Int32
	public let mask: InotifyEventMask
	public let cookie: UInt32
	public let name: String

	public var description: String {
		var parts = ["RawInotifyEvent(wd: \(watchDescriptor), mask: \(mask), name: \"\(name)\""]
		if cookie != 0 { parts.append("cookie: \(cookie)") }
		return parts.joined(separator: ", ") + ")"
	}
}
