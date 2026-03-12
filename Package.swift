// swift-tools-version: 6.0
import PackageDescription

let package = Package(
	name: "Inotify",
	platforms: [.macOS(.v13), .custom("Linux", versionString: "4.4.302")],
	products: [
		.library(
			name: "Inotify",
			targets: ["Inotify"]
		),
		.executable(
			name: "task",
			targets: ["TaskCLI"]
		)
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0"),
		.package(url: "https://github.com/apple/swift-async-algorithms", from: "1.1.3"),
		.package(url: "https://github.com/apple/swift-log", from: "1.10.1"),
		.package(url: "https://github.com/apple/swift-nio", from: "2.95.0"),
		.package(url: "https://github.com/apple/swift-system", from: "1.6.4"),
		.package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.3.0"),
		.package(url: "https://github.com/tuist/Noora", from: "0.55.1")
	],
	targets: [
		.systemLibrary(name: "CInotify"),
		.target(
			name: "Inotify",
			dependencies: [
				"CInotify",
				.product(name: "Logging", package: "swift-log"),
				.product(name: "_NIOFileSystem", package: "swift-nio"),
				.product(name: "SystemPackage", package: "swift-system")
			]
		),
		.testTarget(
			name: "InotifyIntegrationTests",
			dependencies: ["Inotify"],
		),
		.executableTarget(
			name: "TaskCLI",
			dependencies: [
				.product(name: "ArgumentParser", package: "swift-argument-parser"),
				.product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
				.product(name: "Logging", package: "swift-log"),
				.product(name: "Subprocess", package: "swift-subprocess"),
				.product(name: "Noora", package: "Noora")
			]
		)
	]
)
