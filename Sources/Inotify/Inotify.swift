import Dispatch
import CInotify
import SystemPackage

public actor Inotify {
	private let fd: CInt
	private var exclusions = ExclusionList()
	private var watches = InotifyWatchManager()
	private nonisolated(unsafe) let eventReader: any DispatchSourceRead
	private nonisolated let eventStream: AsyncStream<BufferedEvent>
	private nonisolated let continuation: AsyncStream<BufferedEvent>.Continuation
	public nonisolated var events: some AsyncSequence<InotifyEvent, Never> {
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
	public init(bufferingPolicy: AsyncStream<InotifyEvent>.Continuation.BufferingPolicy = .unbounded) throws {
		self.fd = inotify_init1(CInt(IN_NONBLOCK | IN_CLOEXEC))
		guard self.fd >= 0 else {
			throw InotifyError.initFailed(errno: cinotify_get_errno())
		}
		(self.eventReader, self.eventStream, self.continuation) = Self.createEventReader(
			forFileDescriptor: fd,
			bufferingPolicy: Self.bufferedPolicy(for: bufferingPolicy)
		)
	}

	/// Whether an item with this name is skipped, by an excluded name or
	/// an excluded pattern.
	public func isExcluded(_ name: String) -> Bool {
		self.exclusions.excludes(name)
	}

	public func exclude(name: String) {
		self.exclusions.add(name: name)
	}

	public func exclude(names: String...) {
		self.exclude(names: names)
	}

	public func exclude(names: [String]) {
		for name in names {
			self.exclusions.add(name: name)
		}
	}

	/// Excludes every item whose name matches a shell pattern such as
	/// `*.tmp` or `@*`, with the same effect as an excluded name.
	///
	/// The pattern is matched against the item's own name, not its path,
	/// as the shell matches file names: `*` and `?` stand for any
	/// characters and `[…]` for a set of characters. A leading dot needs
	/// no special treatment, so `.*` excludes hidden items.
	public func exclude(pattern: String) {
		self.exclusions.add(pattern: pattern)
	}

	public func exclude(patterns: String...) {
		self.exclude(patterns: patterns)
	}

	public func exclude(patterns: [String]) {
		for pattern in patterns {
			self.exclusions.add(pattern: pattern)
		}
	}

	@discardableResult
	public func addWatch(path: String, mask: InotifyEventMask) throws(InotifyError) -> CInt {
		let wd = inotify_add_watch(self.fd, path, mask.rawValue)
		guard wd >= 0 else {
			throw InotifyError.addWatchFailed(path: path, errno: cinotify_get_errno())
		}
		watches.add(path, withId: wd, mask: mask)
		return wd
	}

	/// Watches `path` and every directory below it, or throws and leaves no
	/// watch behind when one of them cannot be watched.
	@discardableResult
	public func addRecursiveWatch(forDirectory path: String, mask: InotifyEventMask) async throws -> [CInt] {
		let directoryPaths = try await DirectoryResolver.resolve([path], excluding: self.exclusions)
		var result: [CInt] = []
		do {
			for path in directoryPaths {
				result.append(try self.addWatch(path: path.string, mask: mask))
			}
		} catch {
			self.dropWatches(result)
			throw error
		}
		return result
	}

	@discardableResult
	public func addWatchWithAutomaticSubtreeWatching(forDirectory path: String, mask: InotifyEventMask) async throws -> [CInt] {
		let wds = try await self.addRecursiveWatch(forDirectory: path, mask: mask)
		watches.enableAutomaticSubtreeWatching(forIds: wds)
		return wds
	}

	public func removeWatch(_ wd: CInt) throws(InotifyError) {
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

	private func transform(_ buffered: BufferedEvent) async -> InotifyEvent? {
		switch buffered {
		case .event(let event): event
		case .raw(let rawEvent): await transform(rawEvent)
		}
	}

	private func transform(_ rawEvent: RawInotifyEvent) async -> InotifyEvent? {
		if rawEvent.mask.contains(.queueOverflow) {
			return .queueOverflow
		}
		guard let path = self.watches.path(forId: rawEvent.watchDescriptor) else { return nil }
		guard !self.exclusions.excludes(rawEvent.name) else { return nil }
		let event = FileSystemEvent(from: rawEvent, inDirectory: path)
		self.forgetWatchInCaseTheKernelRemovedIt(event)
		self.removeWatchesInCaseADirectoryLeftTheTree(event)
		await self.addWatchInCaseOfAutomaticSubtreeWatching(event)
		return .fileSystem(event)
	}

	/// The kernel reports `IN_IGNORED` once a watch is gone, whether it was
	/// removed explicitly or because its item was deleted or unmounted.
	/// Forgetting it keeps a reused descriptor number from mapping to a
	/// stale path.
	private func forgetWatchInCaseTheKernelRemovedIt(_ event: FileSystemEvent) {
		guard event.mask.contains(.ignored) else { return }
		self.watches.remove(forId: event.watchDescriptor)
	}

	/// A directory moved out of a watched tree keeps its kernel watches,
	/// which would then report events under the old path. Those watches
	/// are removed instead.
	private func removeWatchesInCaseADirectoryLeftTheTree(_ event: FileSystemEvent) {
		guard event.mask.contains(.movedFrom), event.mask.contains(.isDir) else { return }
		self.dropWatches(self.watches.descriptors(under: event.path.string))
	}

	/// Removes watches whose failure does not matter, because their item is
	/// gone or the watches are given up anyway.
	private func dropWatches(_ wds: [CInt]) {
		for wd in wds {
			inotify_rm_watch(self.fd, wd)
			self.watches.remove(forId: wd)
		}
	}

	private func addWatchInCaseOfAutomaticSubtreeWatching(_ event: FileSystemEvent) async {
		guard !event.synthesized,
			  watches.isAutomaticSubtreeWatching(event.watchDescriptor),
			  event.mask.contains(.isDir),
			  let kind = Self.subtreeTrigger(in: event.mask),
			  let mask = self.watches.mask(forId: event.watchDescriptor) else {
			return
		}

		let wds = await self.extendWatches(to: event.path, mask: mask)
		watches.enableAutomaticSubtreeWatching(forIds: wds)
		await self.synthesizeEvents(forContentOfWatches: wds, kind: kind, cookie: event.cookie)
	}

	/// Watches what it can of the tree at `path` and reports the rest as
	/// ``InotifyEvent/watchFailed(path:error:)``. No consumer can catch an
	/// error here, so the events are the only way to tell them.
	private func extendWatches(to path: FilePath, mask: InotifyEventMask) async -> [CInt] {
		let resolution = await DirectoryResolver.resolveTolerantly(path, excluding: self.exclusions)
		for (unreadable, errno) in resolution.unreadable where errno != ENOENT {
			self.report(.listDirectoryFailed(path: unreadable.string, errno: errno), for: unreadable)
		}
		var wds: [CInt] = []
		for directory in resolution.directories {
			do {
				wds.append(try self.addWatch(path: directory.string, mask: mask))
			} catch .addWatchFailed(_, let errno) where errno == ENOENT {
				continue
			} catch .addWatchFailed(_, let errno) where errno == ENOSPC {
				self.report(.addWatchFailed(path: directory.string, errno: errno), for: directory)
				break
			} catch {
				self.report(error, for: directory)
			}
		}
		return wds
	}

	private func report(_ error: InotifyError, for directory: FilePath) {
		self.continuation.yield(.event(.watchFailed(path: directory, error: error)))
	}

	private static func subtreeTrigger(in mask: InotifyEventMask) -> InotifyEventMask? {
		if mask.contains(.create) { return .create }
		if mask.contains(.movedTo) { return .movedTo }
		return nil
	}

	/// Items that already exist when a directory becomes watched never
	/// produce kernel events, so they are reported as if they had just
	/// appeared, marked as synthesized.
	private func synthesizeEvents(forContentOfWatches wds: [CInt], kind: InotifyEventMask, cookie: UInt32) async {
		for wd in wds {
			guard let directory = self.watches.path(forId: wd) else { continue }
			guard let entries = try? await DirectoryResolver.entries(of: FilePath(directory), excluding: self.exclusions) else { continue }
			for entry in entries {
				let mask: InotifyEventMask = entry.isDirectory ? [kind, .isDir] : kind
				self.continuation.yield(.raw(RawInotifyEvent(
					watchDescriptor: wd,
					mask: mask,
					cookie: cookie,
					name: entry.name,
					synthesized: true
				)))
			}
		}
	}

	/// The buffer holds the library's own events next to the kernel's, so
	/// the policy is translated for its element type.
	private static func bufferedPolicy(
		for policy: AsyncStream<InotifyEvent>.Continuation.BufferingPolicy
	) -> AsyncStream<BufferedEvent>.Continuation.BufferingPolicy {
		switch policy {
		case .unbounded: .unbounded
		case .bufferingOldest(let count): .bufferingOldest(count)
		case .bufferingNewest(let count): .bufferingNewest(count)
		@unknown default: .unbounded
		}
	}

	private static func createEventReader(
		forFileDescriptor fd: CInt,
		bufferingPolicy: AsyncStream<BufferedEvent>.Continuation.BufferingPolicy
	) -> (any DispatchSourceRead, AsyncStream<BufferedEvent>, AsyncStream<BufferedEvent>.Continuation) {
		let (stream, continuation) = AsyncStream<BufferedEvent>.makeStream(
			of: BufferedEvent.self,
			bufferingPolicy: bufferingPolicy
		)

		let reader = DispatchSource.makeReadSource(
			fileDescriptor: fd,
			queue: DispatchQueue(label: "Inotify.read", qos: .utility)
		)

		reader.setEventHandler {
			for rawEvent in InotifyEventParser.parse(fromFileDescriptor: fd) {
				continuation.yield(.raw(rawEvent))
			}
		}
		reader.setCancelHandler {
			cinotify_deinit(fd)
			continuation.finish()
		}
		reader.activate()

		return (reader, stream, continuation)
	}

	/// What waits in the buffer: a kernel event, transformed when it is
	/// consumed, or an event the library produced itself.
	enum BufferedEvent: Sendable {
		case raw(RawInotifyEvent)
		case event(InotifyEvent)
	}
}
