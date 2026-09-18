/// What an ``Inotify`` instance delivers: a change to a watched item, or a
/// condition that affects which changes it can deliver.
public enum InotifyEvent: Sendable, Hashable {
	/// A change to a watched file or directory.
	case fileSystem(FileSystemEvent)
	/// The kernel's event queue was full, so it dropped events. Consumers
	/// that must not miss changes should rescan the watched trees.
	case queueOverflow
}
