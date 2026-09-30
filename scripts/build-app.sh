#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
if [[ $# -gt 0 ]]; then shift; fi
# Forward SwiftPM options, including the architectures used by release builds.
bash scripts/swift.sh build --configuration "$configuration" "$@"
binary_dir="$(bash scripts/swift.sh build --configuration "$configuration" "$@" --show-bin-path)"
app="build/A Tale of Todos.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/Tale" "$app/Contents/MacOS/Tale"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp -R "$binary_dir/ATaleOfTodos_TaleApp.bundle" "$app/Contents/Resources/"
if [[ -n "${TALE_APP_VERSION:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $TALE_APP_VERSION" "$app/Contents/Info.plist"
fi
if [[ -n "${TALE_BUILD_NUMBER:-}" ]]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $TALE_BUILD_NUMBER" "$app/Contents/Info.plist"
fi
codesign --force --sign - --entitlements Resources/Tale.entitlements "$app"
printf 'Built %s/%s\n' "$PWD" "$app"
