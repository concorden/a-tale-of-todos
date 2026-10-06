# A Tale of Todos (work in progress)

A calm and *magical* place to think and plan. It's a work in progress. You can download a built app from [Releases](https://github.com/concorden/a-tale-of-todos/releases), once a version has been published, or build it yourself below.

This app exists because I wanted to explore the following:

1. How would it look to combine the keyboard first approach of TUIs with all the good stuff from a GUI.
2. Can I build a UI with a bit more 'flavour'. Mostly inspired by games, where taking an action *feels* good or meaningful.

It also works slightly differently from most note taking apps. It is built for long streams or dumps of notes and todos, rather than individually structured notes.

## How it works

It's a native macOS app written in Swift. It stores your data in a local SQLite db, never connects to the internet, and doesn't require creating an account.

Hold Command (⌘) for half a second to see your tales, then click any tale in the list. `⌘1`–`⌘9` switch immediately to one of the first nine tales, and `⌘N` creates a tale, even before the chooser appears. Escape or releasing Command closes the chooser. When you’re not writing an entry, left and right arrows also switch tales, and `C` copies the selected entry’s text.

## Download and try

Download **A-Tale-of-Todos-macOS.zip** from [Releases](https://github.com/concorden/a-tale-of-todos/releases), unzip it, and drag **A Tale of Todos.app** into Applications. Release builds support Apple Silicon and Intel Macs running **macOS 14 or later**; no developer tools are needed.

The app is ad-hoc signed and not notarized. If macOS blocks the first launch, try opening it, then go to **System Settings → Privacy & Security → Open Anyway** and confirm. See [Apple's instructions](https://support.apple.com/102445).

## Build and run

Requires macOS 14 or later and Swift 6 (Xcode or Apple's Command Line Tools).

```sh
bash scripts/build-app.sh
open "build/A Tale of Todos.app"
```

The script builds and ad-hoc signs a sandboxed `.app` for your Mac's architecture. You can share it with other Macs of the same architecture, though macOS may require the first-launch override described above. Developer ID signing and notarization would remove that extra step. The package can also be opened in Xcode. Use the packaged app to test sandboxing and database bookmarks.

To build and install into your personal Applications folder, replacing an existing copy:

```sh
bash scripts/install-app.sh
open "$HOME/Applications/A Tale of Todos.app"
```

The installer verifies the new app before replacing the old copy. It leaves your database and preferences intact. If the app is already running, quit and reopen it to use the new build. Both build scripts accept `debug` as an optional argument; the default is `release`.

```sh
bash scripts/swift.sh test
```

## Publishing builds

The **Build macOS app** GitHub Actions workflow runs when you push a version tag. It runs the tests, builds a universal app, and attaches the ZIP and SHA-256 checksum to a GitHub Release. It uses a standard macOS runner, which is free for this public repository. There are no scheduled builds or Apple signing credentials to configure.

To publish a new version, first push the code you want to release, then tag that commit:

```sh
git tag v0.1.0
git push origin v0.1.0
```

Use a new tag for each version, such as `v0.1.1`. Tags with a suffix, such as `v0.2.0-beta.1`, create prereleases. The packaged app's version is taken from the tag.

For a build without publishing a release, open [Actions → Build macOS app](https://github.com/concorden/a-tale-of-todos/actions/workflows/release.yml) and click **Run workflow**. Download **A-Tale-of-Todos-macOS** from the completed run's Artifacts section, then unzip it to find the app ZIP and checksum. These artifacts expire after 14 days; release downloads remain available. GitHub requires you to sign in to download workflow artifacts.

To package the same universal ZIP locally:

```sh
bash scripts/package-release.sh v0.1.0
```

The ZIP is written to `build/A-Tale-of-Todos-macOS.zip`. This only packages a build; it does not publish anything. Older Swift toolchains may require selecting a full Xcode installation with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` before the command.

## License

Licensed under the [MIT License](LICENSE). The bundled Cormorant Garamond font is covered by its [SIL Open Font License](Sources/TaleApp/Resources/Fonts/OFL.txt).

## AI disclaimer
Don't look too much at the code - I haven't (yet).
