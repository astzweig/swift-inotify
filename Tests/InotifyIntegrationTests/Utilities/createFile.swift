func createFile(at path: String, contents: String = "") throws {
	try contents.write(toFile: path, atomically: false, encoding: .utf8)
}
