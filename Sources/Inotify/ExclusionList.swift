#if canImport(Musl)
import Musl
#else
import Glibc
#endif

/// The item names an ``Inotify`` instance skips: exact names and shell
/// patterns, both matched against an item's own name.
struct ExclusionList: Sendable {
	private var names: Set<String> = []
	private var patterns: [String] = []

	init(names: Set<String> = [], patterns: [String] = []) {
		self.names = names
		self.patterns = patterns
	}

	mutating func add(name: String) {
		self.names.insert(name)
	}

	mutating func add(pattern: String) {
		guard !self.patterns.contains(pattern) else { return }
		self.patterns.append(pattern)
	}

	/// Patterns are matched as the shell matches file names: `*` and `?`
	/// stand for any characters, `[…]` for a set, and a leading dot needs
	/// no special treatment.
	func excludes(_ name: String) -> Bool {
		self.names.contains(name) || self.patterns.contains { fnmatch($0, name, 0) == 0 }
	}
}
