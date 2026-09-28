# A Tale of Todos

A native, offline macOS scratchpad for notes and todos. SwiftUI and AppKit, backed by the SQLite library included in macOS. No dependencies, accounts, telemetry, or network permissions.

## Build and run

Requires macOS 14 or later and Swift 6 (Xcode or Apple's Command Line Tools).

```sh
bash scripts/build-app.sh
open "build/A Tale of Todos.app"
```

The script builds and ad-hoc signs a sandboxed `.app`. This build is for local use; distribution to other Macs would require Developer ID signing and notarization. The package can also be opened in Xcode. Use the packaged app to test sandboxing and database bookmarks.

```sh
bash scripts/swift.sh test
```

## Keyboard

The app starts in **navigation** mode, with the newest entry selected at the top. Entries run newest to oldest. The composer stays above the stream, with its space always reserved so the list does not resize between modes. In navigation mode, a quiet placeholder offers New note / New todo buttons (or Resume when a draft exists). N / T opens the editor in the same space; Escape or submission returns to the placeholder. A compact keyboard-hint footer and an All / Unfinished filter indicator sit below the stream.

| Key | Action |
| --- | --- |
| N / T | Start or resume a note / todo draft |
| ↑ / ↓ or K / J | Move toward newer / older entries without wrapping |
| X | Toggle the selected todo |
| F | Toggle unfinished todos |
| Enter (input mode) | Save an entry and return to navigation |
| Escape (input mode) | Keep the draft and return to navigation |
| ⌘O | Open / change database |

Notes and todos have independent drafts kept in memory. Quitting or switching databases clears both. Entries support 560 Swift `Character`s (extended grapheme clusters, so an emoji counts as one). Text wraps visually; pasted line breaks become spaces. Overlength drafts remain available for shortening and cannot be submitted. Blank entries do nothing.

Completed todos remain in their original position. In the unfinished view, completion selects the next remaining entry, or the previous one at the end. Starting a note returns to the full stream. Entries cannot yet be edited, deleted, or converted, and search is deferred.

## Tale trees

Choose **View → Appearance → System, Light, or Dark** to change this app's appearance independently of macOS. The choice is remembered between launches; System follows your Mac's current appearance. Light mode uses soft parchment surfaces, warm ink, and muted moss-green accents.

Three intertwined SwiftUI ink strands frame each side of the tale, with irregular bends, varied tapered branch stubs, and occasional forked tips. The two margins have distinct, fixed drawings that stay stable as content changes; their quiet green ink suggests the margins of an illustrated book. The wider illustrated margins extend from the top to the bottom of the window, with the entries, composer, and keyboard guidance between them. A horizontal band of light on both trees follows the list's scroll position: newest entries at the top, oldest at the bottom. Click anywhere along either tree to jump proportionally through the current list. The trees follow the All / Unfinished filter, and the ordinary scroll indicators are hidden. Trackpad, mouse-wheel, and keyboard navigation still work.

Saving a note or todo pulses one independently chosen random strand on each side, once and at the same time, fading out over 1.6 seconds. The trees narrow with the window, support accessibility increment/decrement actions, and omit the pulse's slight expansion when Reduce Motion is enabled. Empty tales have no position glow; tales that fit entirely in view do not scroll when clicked.

## Typography

Space titles and welcome/empty-state headings use bundled Cormorant Garamond by Christian Thalmann, under the SIL Open Font License included in `Sources/TaleApp/Resources/Fonts/OFL.txt`. Entry text and controls retain the native system fonts.

## Timestamps

Each entry displays its permanent SQLite-generated integer ID beside the timestamp, starting at `#1` and increasing across both notes and todos within each database. Filtering or completing an entry never changes its ID.

Timestamps refresh every 30 seconds in local time: `just now`, minutes or hours ago for today, `yesterday HH:mm`, then weekdays for 2–6 days ago. After 7 days they use `d MMM HH:mm`, including the year when different from the current year. Calendar boundaries take priority over elapsed hours. Hover over a timestamp to see the full date and time.

## Your database

Create or open a database using the first-launch screen. The app remembers the selected file with a security-scoped bookmark. It will never silently create a replacement for a missing database. File → Change Database switches files. Opening an unrelated SQLite file is rejected.

Entries are committed immediately using SQLite transactions. The database uses an application ID (`ATOD`) and schema version 1. A temporary SQLite rollback-journal file can exist next to the database while saving. To back up or move the database, quit the app first and copy the `.sqlite` file. Prefer a local folder rather than a cloud-synced location.

The app sandbox grants access only to user-selected files and their stored bookmarks. It has no inbound or outbound network entitlements. The app contains no networking code or third-party libraries.

SQLite journal access uses Apple's [related-file coordination](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox). New databases are initialized in the app's temporary container before being copied to the chosen location, so first launch doesn't need access to the entire containing folder.
