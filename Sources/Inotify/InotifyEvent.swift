import SystemPackage

/// What an ``Inotify`` instance delivers: a change to a watched item, or a
/// condition that affects which changes it can deliver.
public enum InotifyEvent: Sendable, Hashable {
	/// A change to a watched file or directory.
	case fileSystem(FileSystemEvent)
	/// The kernel's event queue was full, so it dropped events. Consumers
	/// that must not miss changes should rescan the watched trees.
	case queueOverflow
	/// A directory that appeared in a tree watched with automatic subtree
	/// watching could not be watched, so changes below it go unreported.
	///
	/// It follows the event of the directory whose appearance made the
	/// library extend the watch. A reached watch limit ends the extension,
	/// so the directories after the first failed one are not reported
	/// separately. A directory that vanished before it could be watched is
	/// not reported, since its removal arrives as an event of its own.
	case watchFailed(path: FilePath, error: InotifyError)
}
