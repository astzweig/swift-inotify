#!/usr/bin/env zsh

# task - Run the package's TaskCLI target via a transient "task" product.
#
# Works around https://github.com/swiftlang/swift-package-manager/issues/8482
# by temporarily adding an executable product named "task" to Package.swift,
# running it with `swift run`, and restoring the original manifest afterwards.
#
# Usage:  task [arguments...]
#
# The script auto-detects the package name from Package.swift and expects an
# executable target named "<PackageName>TaskCLI" to exist.

set -euo pipefail

# --- Resolve the package root (search upward for Package.swift) -----------

package_root="${PWD}"
while [[ ! -f "${package_root}/Package.swift" ]]; do
	package_root="${package_root:h}"            # zsh dirname
	if [[ "${package_root}" == "/" ]]; then
		echo "error: Could not find Package.swift in any parent directory." >&2
		exit 1
	fi
done

manifest="${package_root}/Package.swift"
backup="${manifest}.task-backup"

# --- Extract the package name ---------------------------------------------

package_name=$(sed -n 's/^.*name:[[:space:]]*"\([^"]*\)".*/\1/p' "${manifest}" | head -1)
if [[ -z "${package_name}" ]]; then
	echo "error: Could not determine package name from ${manifest}." >&2
	exit 1
fi

target_name="${package_name}TaskCLI"

# --- Cleanup trap (runs on EXIT — covers success, failure, signals) -------

function cleanup {
	if [[ -f "${backup}" ]]; then
		mv -f "${backup}" "${manifest}"
	fi
}
trap cleanup EXIT

# --- Inject the transient "task" product ----------------------------------

cp -f "${manifest}" "${backup}"

swift package --package-path "${package_root}" \
	add-product task --type executable --targets "${target_name}"

# --- Run it (forward all script arguments) --------------------------------

swift run --package-path "${package_root}" task "$@"
