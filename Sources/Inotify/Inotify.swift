import Dispatch
import CInotify

public actor Inotify {
	private let fd: CInt
	private var watches = InotifyWatchManager()
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
		watches.add(path, withId: wd, mask: mask)
		return wd
	}

	@discardableResult
	public func addRecursiveWatch(forDirectory path: String, mask: InotifyEventMask) async throws -> [CInt] {
		let directoryPaths = try await DirectoryResolver.resolve(path)
		var result: [CInt] = []
		for path in directoryPaths {
			let wd = try self.addWatch(path: path.string, mask: mask)
			result.append(wd)
		}
		return result
	}

	@discardableResult
	public func addWatchWithAutomaticSubtreeWatching(forDirectory path: String, mask: InotifyEventMask) async throws -> [CInt] {
		let wds = try await self.addRecursiveWatch(forDirectory: path, mask: mask)
		watches.enableAutomaticSubtreeWatching(forIds: wds)
		return wds
	}

	public func removeWatch(_ wd: CInt) throws {
		guard inotify_rm_watch(self.fd, wd) == 0 else {
			throw InotifyError.removeWatchFailed(watchDescriptor: wd, errno: cinotify_get_errno())
		}
		watches.remove(forId: wd)
	}

	deinit {
		cinotify_deinit(self.fd)
	}

	private func transform(_ rawEvent: RawInotifyEvent) async -> InotifyEvent? {
		guard let path = self.watches.path(forId: rawEvent.watchDescriptor) else { return nil }
		let event = InotifyEvent.init(from: rawEvent, inDirectory: path)
		await self.addWatchInCaseOfAutomaticSubtreeWatching(event)
		return InotifyEvent.init(from: rawEvent, inDirectory: path)
	}

	private func addWatchInCaseOfAutomaticSubtreeWatching(_ event: InotifyEvent) async {
		guard watches.isAutomaticSubtreeWatching(event.watchDescriptor),
			  event.mask.contains(.create),
			  event.mask.contains(.isDir) else {
			return
		}

		guard let mask = self.watches.mask(forId: event.watchDescriptor) else { return }
		let _ = try? await self.addWatchWithAutomaticSubtreeWatching(forDirectory: event.path.string, mask: mask)
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
