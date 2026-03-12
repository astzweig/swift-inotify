import ArgumentParser

@main
struct Command: AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Project tasks of Astzweig's Swift Inotify project.",
		subcommands: [TestCommand.self, GenerateDocumentationCommand.self]
	)
}
