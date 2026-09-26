#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Keep compiler and SwiftPM caches in the project, including in restricted workspaces.
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
extra_args=(--disable-sandbox --cache-path .build/cache --config-path .build/config --security-path .build/security)
# Some Command Line Tools releases omit the bundled Testing macro search path.
if [[ "${1:-}" == "test" ]]; then
    testing_plugins="$(dirname "$(dirname "$(xcrun --find swift)")")/lib/swift/host/plugins/testing"
    if [[ -d "$testing_plugins" ]]; then
        extra_args+=(-Xswiftc -plugin-path -Xswiftc "$testing_plugins")
    fi
fi
exec swift "$@" "${extra_args[@]}"
