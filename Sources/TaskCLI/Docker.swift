struct Docker {
	static func getLinuxPlatformStringWithHostArchitecture() -> String {
		#if arch(x86_64)
		return "linux/amd64"
		#else
		return "linux/arm64"
		#endif
	}
}