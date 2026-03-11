import Foundation

func withTempDir(_ body: (String) async throws -> Void) async throws {
	let dir = FileManager.default.temporaryDirectory
		.appendingPathComponent("InotifyIntegrationTests-\(UUID().uuidString)")
		.path
	try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
	defer { try? FileManager.default.removeItem(atPath: dir) }
	try await body(dir)
}
