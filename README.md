# A Tale of Todos (work in progress)

A calm and *magical* place to think and plan. It's a work in progress and if you want to try it, you'll have to build it (see the **Build and run** section below).

This app exists because I wanted to explore the following:

1. How would it look to combine the keyboard first approach of TUIs with all the good stuff from a GUI.
2. Can I build a UI with a bit more 'flavour'. Mostly inspired by games, where taking an action *feels* good or meaningful.

It also works slightly differently from most note taking apps. It is built for long streams or dumps of notes and todos, rather than individually structured notes.

## How it works

It's a native macOS app written in Swift. It stores your data in a local SQLite db, never connects to the internet, and doesn't require creating an account.

## Build and run

Requires macOS 14 or later and Swift 6 (Xcode or Apple's Command Line Tools).

```sh
bash scripts/build-app.sh
open "build/A Tale of Todos.app"
```

The script builds and ad-hoc signs a sandboxed `.app`. This build is for local use; distribution to other Macs would require Developer ID signing and notarization. The package can also be opened in Xcode. Use the packaged app to test sandboxing and database bookmarks.

To build and install into your personal Applications folder, replacing an existing copy:

```sh
bash scripts/install-app.sh
open "$HOME/Applications/A Tale of Todos.app"
```

The installer verifies the new app before replacing the old copy. It leaves your database and preferences intact. If the app is already running, quit and reopen it to use the new build. Both build scripts accept `debug` as an optional argument; the default is `release`.

```sh
bash scripts/swift.sh test
```

## AI disclaimer
Don't look too much at the code - I haven't (yet).

