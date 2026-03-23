import ArgumentParser
import Foundation
import Noora
import Subprocess

struct TestCommand: AsyncParsableCommand {
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

		noora.info("Running tests on Linux.")
		logger.debug("Current directory", metadata: ["current-directory": "\(currentDirectory)"])
		let dockerRunResult = try await Subprocess.run(
			.name("docker"),
			arguments: [
				"run",
				"-v", "\(currentDirectory):/code",
				"-v", "swift-inotify-build-cache:/code/.build",
				"--security-opt", "systempaths=unconfined",
				"--platform", Docker.getLinuxPlatformStringWithHostArchitecture(),
				"-w", "/code", "swift:latest",
				"/bin/bash", "-c", "swift test --skip InotifyLimitTests; swift test --skip-build --filter InotifyLimitTests"
			],
			output: .standardOutput,
			error: .standardError
		)
		if dockerRunResult.terminationStatus.isSuccess {
			noora.success("All tests completed successfully.")
		} else {
			noora.error("Not all tests completed successfully.")
		}
	}
}
