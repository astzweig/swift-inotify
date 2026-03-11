import Dispatch
import CInotify

public actor Inotify {
	private let fd: CInt
	private var watches: [CInt: String] = [:]
	private var eventReader: any DispatchSourceRead
	private var eventStream: AsyncStream<RawInotifyEvent>
	public var events: AsyncCompactMapSequence<AsyncStream<RawInotifyEvent>, InotifyEvent> {
		self.eventStream.compactMap(self.transform(_:))
	}

	public init() throws {
		self.fd = inotify_init1(CInt(IN_NONBLOCK | IN_CLOEXEC))
		guard self.fd >= 0 else {
			throw InotifyError.initFailed(errno: cinotify_get_errno())
		}
		(self.eventReader, self.eventStream) = Self.createEventReader(forFileDescriptor: fd)
	}

	@discardableResult
	public func addWatch(path: String, mask: InotifyEventMask) throws -> CInt {
		let wd = inotify_add_watch(self.fd, path, mask.rawValue)
		guard wd >= 0 else {
			throw InotifyError.addWatchFailed(path: path, errno: cinotify_get_errno())
		}
		watches[wd] = path
		return wd
	}

	public func removeWatch(_ wd: CInt) throws {
		guard inotify_rm_watch(self.fd, wd) == 0 else {
			throw InotifyError.removeWatchFailed(watchDescriptor: wd, errno: cinotify_get_errno())
		}
		watches.removeValue(forKey: wd)
	}

	deinit {
		cinotify_deinit(self.fd)
	}

	private func transform(_ rawEvent: RawInotifyEvent) -> InotifyEvent? {
		guard let path = self.watches[rawEvent.watchDescriptor] else { return nil }
		return InotifyEvent.init(from: rawEvent, inDirectory: path)
	}

	private static func createEventReader(forFileDescriptor fd: CInt) -> (any DispatchSourceRead, AsyncStream<RawInotifyEvent>) {
		let (stream, continuation) = AsyncStream<RawInotifyEvent>.makeStream(
			of: RawInotifyEvent.self,
			bufferingPolicy: .bufferingNewest(512)
		)

		let reader = DispatchSource.makeReadSource(
			fileDescriptor: fd,
			queue: DispatchQueue(label: "Inotify.read", qos: .utility)
		)

		reader.setEventHandler {
			for rawEvent in InotifyEventParser.parse(fromFileDescriptor: fd) {
				continuation.yield(rawEvent)
			}
		}
		reader.setCancelHandler {
			continuation.finish()
		}
		reader.activate()

		return (reader, stream)
	}
}
