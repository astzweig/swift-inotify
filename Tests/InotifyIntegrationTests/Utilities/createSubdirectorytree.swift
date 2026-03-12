import Foundation
import SystemPackage

func createSubdirectorytree(at dir: String, foldersPerLevel: Int, levels: Int) throws {
	let fileManager = FileManager.default

	for path in SubfolderTreeIterator(basePath: dir, foldersPerLevel: foldersPerLevel, levels: levels) {
		try fileManager.createDirectory(
			at: path,
			withIntermediateDirectories: true,
			attributes: nil
		)
	}
}

struct SubfolderTreeIterator: IteratorProtocol, Sequence {
	let basePath: URL
	let foldersPerLevel: Int
	let levels: Int
	private var indices: [Int]
	private var done = false

	init(basePath: String, foldersPerLevel: Int, levels: Int) {
		self.basePath = URL(filePath: basePath)
		self.foldersPerLevel = foldersPerLevel
		self.levels = levels
		self.indices = Array(repeating: 1, count: levels)
	}

	mutating func next() -> URL? {
		guard !done else { return nil }

		let path = indices.reduce(basePath) { partialPath, index in
			partialPath.appending(path: "Folder \(index)")
		}

		// Advance indices (odometer-style, rightmost increments first)
		var carry = true
		for i in (0..<levels).reversed() {
			if carry {
				indices[i] += 1
				if indices[i] > foldersPerLevel {
					indices[i] = 1
				} else {
					carry = false
				}
			}
		}
		if carry { done = true }

		return path
	}
}
