struct InotifyWatchManager {
	private var watchPaths: [CInt: String] = [:]
	private var activeWatches: Set<CInt> = []

	mutating func add(_ path: String, withId watchDescriptor: CInt) {
		self.watchPaths[watchDescriptor] = path
		self.activeWatches.insert(watchDescriptor)
	}

	mutating func remove(forId watchDescriptor: CInt) {
		self.watchPaths.removeValue(forKey: watchDescriptor)
		self.activeWatches.remove(watchDescriptor)
	}

	func path(forId watchDescriptor: CInt) -> String? {
		return self.watchPaths[watchDescriptor]
	}
}
