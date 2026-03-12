import Foundation

func withInotifyWatchLimit(of limit: Int, _ body: () async throws -> Void) async throws {
	let confPath = URL(filePath: "/proc/sys/fs/inotify")
	let filenames = ["max_user_watches", "max_user_instances", "max_queued_events"]
	var previousLimits: [String: String] = [:]

	for filename in filenames {
		let filePath = confPath.appending(path: filename)
		let currentLimit = try String(contentsOf: filePath, encoding: .utf8)
		previousLimits[filename] = currentLimit
		try "\(limit)".write(to: filePath, atomically: false, encoding: .utf8)
	}

	try await body()

	for filename in filenames {
		let filePath = confPath.appending(path: filename)
		guard let previousLimit = previousLimits[filename] else { continue }
		try previousLimit.write(to: filePath, atomically: false, encoding: .utf8)
	}
}
