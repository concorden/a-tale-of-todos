#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Accept a version tag, or use the checked-in app version for manual builds.
version="${1:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)}"
version="${version#v}"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[[:alnum:].-]+)?$ ]]; then
    printf 'Expected a version like v0.1.0 or v0.1.0-beta.1; got %s\n' "$version" >&2
    exit 1
fi
export TALE_APP_VERSION="${version%%-*}"
export TALE_BUILD_NUMBER="${GITHUB_RUN_NUMBER:-1}"

# Build both architectures in one app, including the shared resource bundle.
bash scripts/build-app.sh release --arch arm64 --arch x86_64

app="build/A Tale of Todos.app"
archive="build/A-Tale-of-Todos-macOS.zip"
for architecture in arm64 x86_64; do
    xcrun lipo "$app/Contents/MacOS/Tale" -verify_arch "$architecture"
done
codesign --verify --deep --strict "$app"
plutil -lint "$app/Contents/Info.plist"

# ditto preserves the app bundle's executable permissions and macOS metadata.
rm -f "$archive"
ditto -c -k --sequesterRsrc --keepParent "$app" "$archive"
(cd build && shasum -a 256 A-Tale-of-Todos-macOS.zip > A-Tale-of-Todos-macOS.zip.sha256)
printf 'Packaged %s/%s\n' "$PWD" "$archive"
