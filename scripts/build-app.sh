#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
configuration="${1:-release}"
bash scripts/swift.sh build --configuration "$configuration"
binary_dir="$(bash scripts/swift.sh build --configuration "$configuration" --show-bin-path)"
app="build/A Tale of Todos.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$binary_dir/Tale" "$app/Contents/MacOS/Tale"
cp Resources/Info.plist "$app/Contents/Info.plist"
codesign --force --sign - --entitlements Resources/Tale.entitlements "$app"
printf 'Built %s/%s\n' "$PWD" "$app"
