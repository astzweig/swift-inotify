import ArgumentParser
import Logging

struct GlobalOptions: ParsableArguments {
	@Flag(
		name: .short,
		help: "Increase logging verbosity. Use -v, -vv, or -vvv."
	)
	var verbose: Int

	var logLevel: Logger.Level {
		switch verbose {
		case 0: return .notice
		case 1: return .info
		case 2: return .debug
		default: return .trace
		}
	}

	func makeLogger(labeled label: String) -> Logger {
		var logger = Logger(label: label)
		logger.logLevel = logLevel
		return logger
	}
}
