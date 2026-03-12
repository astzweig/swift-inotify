struct InotifyWatchManager {
	private var watchPaths: [CInt: String] = [:]
	private var watchMasks: [CInt: InotifyEventMask] = [:]
	private var activeWatches: Set<CInt> = []
	private var watchesWithAutomaticSubtreeWatching: Set<CInt> = []

	mutating func add(_ path: String, withId watchDescriptor: CInt, mask: InotifyEventMask) {
		self.watchPaths[watchDescriptor] = path
		self.watchMasks[watchDescriptor] = mask
		self.activeWatches.insert(watchDescriptor)
	}

	mutating func enableAutomaticSubtreeWatching(forId watchDescriptor: CInt) {
		assert(self.activeWatches.contains(watchDescriptor))
		self.watchesWithAutomaticSubtreeWatching.insert(watchDescriptor)
	}

	mutating func enableAutomaticSubtreeWatching(forIds watchDescriptors: CInt...) {
		self.enableAutomaticSubtreeWatching(forIds: watchDescriptors)
	}

	mutating func enableAutomaticSubtreeWatching(forIds watchDescriptors: [CInt]) {
		for watchDescriptor in watchDescriptors {
			self.enableAutomaticSubtreeWatching(forId: watchDescriptor)
		}
	}

	mutating func remove(forId watchDescriptor: CInt) {
		self.watchPaths.removeValue(forKey: watchDescriptor)
		self.watchMasks.removeValue(forKey: watchDescriptor)
		self.activeWatches.remove(watchDescriptor)
		self.watchesWithAutomaticSubtreeWatching.remove(watchDescriptor)
	}

	func path(forId watchDescriptor: CInt) -> String? {
		return self.watchPaths[watchDescriptor]
	}

	func mask(forId watchDescriptor: CInt) -> InotifyEventMask? {
		return self.watchMasks[watchDescriptor]
	}

	func isAutomaticSubtreeWatching(_ watchDescriptor: CInt) -> Bool {
		return self.watchesWithAutomaticSubtreeWatching.contains(watchDescriptor)
	}
}
