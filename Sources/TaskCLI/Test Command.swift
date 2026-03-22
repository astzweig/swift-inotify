import Foundation
import Script
import Noora

struct TestCommand: Script {
	static let configuration = CommandConfiguration(
		commandName: "test",
		abstract: "Run swift test in a linux container.",
		aliases: ["t"],
	)

	@OptionGroup var global: GlobalOptions

	// MARK: - Run

	func run() async throws {
		let noora = Noora()
		let logger = global.makeLogger(labeled: "swift-inotify.cli.task.test")
		let currentDirectory = FileManager.default.currentDirectoryPath
		let docker = try await executable(named: "docker")

		noora.info("Running tests on Linux.")
		logger.debug("Current directory", metadata: ["current-directory": "\(currentDirectory)"])
		do {
			try await docker(
				"run",
				"-v", "\(currentDirectory):/code",
				"--security-opt", "systempaths=unconfined",
				"--platform", "linux/arm64",
				"-w", "/code", "swift:latest",
				"/bin/bash", "-c", "swift test --skip InotifyLimitTests; swift test --skip-build --filter InotifyLimitTests"
			)
			noora.success("All tests completed successfully.")
		} catch {
			noora.error("Not all tests completed successfully.")
		}
	}
}
