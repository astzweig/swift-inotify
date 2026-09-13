import Dispatch
import CInotify

public actor Inotify {
	private let fd: CInt
	private var excludedItemNames: Set<String> = []
	private var watches = InotifyWatchManager()
	private nonisolated(unsafe) let eventReader: any DispatchSourceRead
	private nonisolated let eventStream: AsyncStream<RawInotifyEvent>
	public nonisolated var events: AsyncCompactMapSequence<AsyncStream<RawInotifyEvent>, InotifyEvent> {
		self.eventStream.compactMap(self.transform(_:))
	}

	/// Creates an inotify instance.
	///
	/// Events are read from the kernel as soon as they arrive and buffered
	/// until they are consumed from ``events``.
	///
	/// - Parameter bufferingPolicy: How events are kept while no consumer is
	///   reading ``events``. The default `.unbounded` keeps every event, so a
	///   burst of changes is never lost; a bounded policy trades memory for
	///   dropped events.
	public init(bufferingPolicy: AsyncStream<RawInotifyEvent>.Continuation.BufferingPolicy = .unbounded) throws {
		self.fd = inotify_init1(CInt(IN_NONBLOCK | IN_CLOEXEC))
		guard self.fd >= 0 else {
			throw InotifyError.initFailed(errno: cinotify_get_errno())
		}
		(self.eventReader, self.eventStream) = Self.createEventReader(
			forFileDescriptor: fd,
			bufferingPolicy: bufferingPolicy
		)
	}

	public func isExcluded(_ name: String) -> Bool {
		self.excludedItemNames.contains(name)
	}

	public func exclude(name: String) {
		self.excludedItemNames.insert(name)
	}

	public func exclude(names: String...) {
		self.exclude(names: names)
	}

	public func exclude(names: [String]) {
		for name in names {
			self.excludedItemNames.insert(name)
		}
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
		let directoryPaths = try await DirectoryResolver.resolve(path, excluding: self.excludedItemNames)
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
		// The file descriptor is closed by the reader's cancel handler once
		// libdispatch has unregistered it. Closing it here would leave a
		// registration behind that a later instance reusing the descriptor
		// number could inherit, silently losing its events.
		self.eventReader.cancel()
	}

	private func transform(_ rawEvent: RawInotifyEvent) async -> InotifyEvent? {
		if rawEvent.mask.contains(.queueOverflow) {
			return InotifyEvent(from: rawEvent, inDirectory: "")
		}
		guard let path = self.watches.path(forId: rawEvent.watchDescriptor) else { return nil }
		guard !self.excludedItemNames.contains(rawEvent.name) else { return nil }
		let event = InotifyEvent.init(from: rawEvent, inDirectory: path)
		self.forgetWatchInCaseTheKernelRemovedIt(event)
		self.removeWatchesInCaseADirectoryLeftTheTree(event)
		await self.addWatchInCaseOfAutomaticSubtreeWatching(event)
		return event
	}

	/// The kernel reports `IN_IGNORED` once a watch is gone, whether it was
	/// removed explicitly or because its item was deleted or unmounted.
	/// Forgetting it keeps a reused descriptor number from mapping to a
	/// stale path.
	private func forgetWatchInCaseTheKernelRemovedIt(_ event: InotifyEvent) {
		guard event.mask.contains(.ignored) else { return }
		self.watches.remove(forId: event.watchDescriptor)
	}

	/// A directory moved out of a watched tree keeps its kernel watches,
	/// which would then report events under the old path. Those watches
	/// are removed instead.
	private func removeWatchesInCaseADirectoryLeftTheTree(_ event: InotifyEvent) {
		guard event.mask.contains(.movedFrom), event.mask.contains(.isDir) else { return }
		for wd in self.watches.descriptors(under: event.path.string) {
			inotify_rm_watch(self.fd, wd)
			self.watches.remove(forId: wd)
		}
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

	private static func createEventReader(
		forFileDescriptor fd: CInt,
		bufferingPolicy: AsyncStream<RawInotifyEvent>.Continuation.BufferingPolicy
	) -> (any DispatchSourceRead, AsyncStream<RawInotifyEvent>) {
		let (stream, continuation) = AsyncStream<RawInotifyEvent>.makeStream(
			of: RawInotifyEvent.self,
			bufferingPolicy: bufferingPolicy
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
			cinotify_deinit(fd)
			continuation.finish()
		}
		reader.activate()

		return (reader, stream)
	}
}
