// The mask lives in its own module so that it is usable off Linux; users
// of `Inotify` keep seeing it as before.
@_exported import InotifyMask
