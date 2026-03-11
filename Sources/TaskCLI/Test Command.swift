import ArgumentParser
import AsyncAlgorithms
import Foundation
import Subprocess
import Noora

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
		async let monitorResult = Subprocess.run(
			.name("docker"),
			arguments: ["run", "-v", "\(currentDirectory):/code", "--platform", "linux/arm64", "-w", "/code", "swift:latest", "swift", "test"],
			preferredBufferSize: 10,
		) { execution, standardInput, standardOutput, standardError in
			print("")
			let stdout = standardOutput.lines()
			let stderr = standardError.lines()
			for try await line in merge(stdout, stderr) {
				noora.passthrough("\(line)")
			}
			print("")
		}

		if (try await monitorResult.terminationStatus.isSuccess) {
			noora.success("All tests completed successfully.")
		} else {
			noora.error("Not all tests completed successfully.")
		}
	}
}
