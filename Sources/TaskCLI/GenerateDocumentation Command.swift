import ArgumentParser
import AsyncAlgorithms
import Foundation
import Logging
import Noora
import Subprocess

struct GenerateDocumentationCommand: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "generate-documentation",
		abstract: "Generate DocC documentation of all targets inside a Linux container.",
		aliases: ["gd"],
	)

	@OptionGroup var global: GlobalOptions

	private static let doccPluginURL = "https://github.com/apple/swift-docc-plugin.git"
	private static let doccPluginMinVersion = "1.4.0"
	private static let skipItems: Set<String> = [".git", ".build", ".swiftpm", "public"]

	// MARK: - Run

	func run() async throws {
		let noora = Noora()
		let logger = global.makeLogger(labeled: "swift-inotify.cli.task.generate-documentation")
		let fileManager = FileManager.default
		let projectDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)

		let targets = try await Self.targets(for: projectDirectory)

		noora.info("Generating DocC documentation on Linux.")
		logger.debug("Current directory", metadata: ["current-directory": "\(projectDirectory.path(percentEncoded: false))", "targets": "\(targets.joined(separator: ", "))"])

		let tempDirectory = try copyProject(from: projectDirectory)
		logger.info("Copied project to temporary directory.", metadata: ["path": "\(tempDirectory.path(percentEncoded: false))"])

		defer {
			try? fileManager.removeItem(at: tempDirectory)
			logger.info("Cleaned up temporary directory.")
		}

		try await injectDoccPluginDependency(in: tempDirectory, logger: logger)
		let script = Self.makeRunScript(for: targets)

		logger.debug("Container script", metadata: ["script": "\(script)"])
		let dockerResult = try await Subprocess.run(
			.name("docker"),
			arguments: [
				"run", "--rm",
				"-v", "\(tempDirectory.path(percentEncoded: false)):/code",
				"--platform", "linux/arm64",
				"-w", "/code",
				"swift:latest",
				"/bin/bash", "-c", script,
			],
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

		guard dockerResult.terminationStatus.isSuccess else {
			noora.error("Documentation generation failed.")
			return
		}

		try copyResults(from: tempDirectory, to: projectDirectory)
		try Self.generateIndexHTML(
			templateURL: projectDirectory.appending(path: ".github/workflows/index.tpl.html"),
			outputURL: projectDirectory.appending(path: "public/index.html")
		)

		noora.success(
			.alert("Documentation generated successfully.",
				takeaways: ["Start a local web server with ./public as document root, i.e. with python3 -m http.server to browse the documentation."]
			)
		)
	}
	
	private static func generateIndexHTML(templateURL: URL, outputURL: URL) throws {
		var content = try String(contentsOf: templateURL, encoding: .utf8)

		let replacements: [(String, String)] = [
			("{{project.name}}", "Swift Inotify"),
			("{{project.tagline}}", "🗂️ Monitor filesystem events on Linux using modern Swift concurrency"),
			("{{project.links}}", """
				<li><a href="inotify/documentation/inotify/">Inotify</a>: The actual library.</li>\
				<li><a href="inotifytaskcli/documentation/inotifytaskcli/">TaskCLI</a>: The project build command.</li>
				"""),
		]

		for (placeholder, value) in replacements {
			content = content.replacingOccurrences(of: placeholder, with: value)
		}

		try FileManager.default.createDirectory(
			at: outputURL.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try content.write(to: outputURL, atomically: true, encoding: .utf8)
	}

	private static func targets(for projectDirectory: URL) async throws -> [String] {
		let packages = try await Self.packageTargets()
		var packagesWithDoccFolder: [(name: String, path: String)] = []
		for package in packages {
			guard try await DoccFinder.hasDoccFolder(at: package.path) else { continue }
			packagesWithDoccFolder.append(package)
		}
		return packagesWithDoccFolder.map { $0.name }
	}

	private static func packageTargets() async throws -> [(name: String, path: String)] {
		let packageDescription = try await Subprocess.run(
			.name("swift"),
			arguments: ["package", "describe", "--type", "json"],
			output: .data(limit: 20_000)
		)

		struct PackageDescription: Codable {
			let targets: [Target]
		}
		struct Target: Codable {
			let name: String
			let path: String
		}

		let package = try JSONDecoder().decode(PackageDescription.self, from: packageDescription.standardOutput)
		return package.targets.map { ($0.name, $0.path) }
	}

	private static func makeRunScript(for targets: [String]) -> String {
		targets.map {
			"mkdir -p \"./public/\($0.localizedLowercase)\" && " +
			"swift package --allow-writing-to-directory \"\($0.localizedLowercase)\" " +
			"generate-documentation --disable-indexing --transform-for-static-hosting " +
			"--target \"\($0)\" " +
			"--hosting-base-path \"\($0.localizedLowercase)\" " +
			"--output-path \"./public/\($0.localizedLowercase)\""
		}.joined(separator: " && ")
	}

	// MARK: - Project Copy

	private func copyProject(from source: URL) throws -> URL {
		let fileManager = FileManager.default
		let tempDirectory = fileManager.temporaryDirectory.appending(path: "swift-inotify-docs-\(UUID().uuidString)")
		try fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

		let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
		for item in contents {
			guard !Self.skipItems.contains(item.lastPathComponent) else { continue }
			try fileManager.copyItem(at: item, to: tempDirectory.appending(path: item.lastPathComponent))
		}

		return tempDirectory
	}

	private func copyResults(from tempDirectory: URL, to projectDirectory: URL) throws {
		let fileManager = FileManager.default
		let source = tempDirectory.appending(path: "public")
		let destination = projectDirectory.appending(path: "public")

		if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
			try fileManager.removeItem(at: destination)
		}
		try fileManager.copyItem(at: source, to: destination)
	}

	// MARK: - Dependency Injection

	private func injectDoccPluginDependency(in directory: URL, logger: Logger) async throws {
		let result = try await Subprocess.run(
			.name("swift"),
			arguments: [
				"package", "--package-path", directory.path(percentEncoded: false),
				"add-dependency", "--from", Self.doccPluginMinVersion, Self.doccPluginURL
			],
		) { _ in }

		guard result.terminationStatus.isSuccess else {
			throw GenerateDocumentationError.dependencyInjectionFailed
		}

		logger.info("Injected swift-docc-plugin dependency.")
	}
}

enum GenerateDocumentationError: Error, CustomStringConvertible {
	case dependencyInjectionFailed

	var description: String {
		switch self {
		case .dependencyInjectionFailed:
			"Failed to add swift-docc-plugin dependency to Package.swift."
		}
	}
}
