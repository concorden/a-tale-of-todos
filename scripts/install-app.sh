#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

bash scripts/build-app.sh "${1:-release}"

applications_dir="$HOME/Applications"
destination="$applications_dir/A Tale of Todos.app"
mkdir -p "$applications_dir"
staging_dir="$(mktemp -d "$applications_dir/.tale-install.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT

# Finish copying and verifying before replacing the installed app.
ditto "build/A Tale of Todos.app" "$staging_dir/A Tale of Todos.app"
codesign --verify --deep --strict "$staging_dir/A Tale of Todos.app"

if [[ -e "$destination" || -L "$destination" ]]; then
    mv "$destination" "$staging_dir/previous.app"
fi
if ! mv "$staging_dir/A Tale of Todos.app" "$destination"; then
    if [[ -e "$staging_dir/previous.app" || -L "$staging_dir/previous.app" ]]; then
        # Keep the previous copy available even if restoring it also fails.
        if ! mv "$staging_dir/previous.app" "$destination"; then
            trap - EXIT
            printf 'Previous app preserved at %s\n' "$staging_dir/previous.app" >&2
        fi
    fi
    exit 1
fi

printf 'Installed %s\n' "$destination"
