import Foundation

enum InotifyLimit: String, CaseIterable {
	case userWatches = "max_user_watches"
	case userInstances = "max_user_instances"
	case queuedEvents = "max_queued_events"
}

func withInotifyWatchLimit(
	of limit: Int,
	for limits: [InotifyLimit] = InotifyLimit.allCases,
	_ body: () async throws -> Void
) async throws {
	let confPath = URL(filePath: "/proc/sys/fs/inotify")
	let filenames = limits.map(\.rawValue)
	var previousLimits: [String: String] = [:]

	defer {
		for filename in filenames {
			let filePath = confPath.appending(path: filename)
			guard let previousLimit = previousLimits[filename] else { continue }
			try? previousLimit.write(to: filePath, atomically: false, encoding: .utf8)
		}
	}

	for filename in filenames {
		let filePath = confPath.appending(path: filename)
		let currentLimit = try String(contentsOf: filePath, encoding: .utf8)
		previousLimits[filename] = currentLimit
		try "\(limit)".write(to: filePath, atomically: false, encoding: .utf8)
	}

	try await body()
}
