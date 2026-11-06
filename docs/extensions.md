# Extending Tendedero

Tendedero watches folders and hangs what it finds there. Most extensions are
a few lines in one place, and this is where they go.

## Another screenshot app

macOS tags the files it takes with an extended attribute, so Tendedero can
tell its own screenshots apart from anything else on the Desktop. Other apps
write their own files without that tag, so they are found by the folder they
save to and by the names they give their files.

`TendederoCore/Sources/TendederoCore/CaptureApps.swift` holds what Tendedero
knows about them. Each app is one entry in `CaptureApps.known`:

| field | what it says |
|---|---|
| `id` | a short name, to remember whether the user turned it off |
| `name` | the name shown in the menu |
| `appNames` | the bundle names to look for in `/Applications` |
| `extraPrefixes` | the names it gives its files that are not its own name |
| `settings` | reads the app's own settings, when they are kept where we know |

Adding an app is one entry. Nothing else has to be told about it:

- **Where to look** is known already. Pictures land in `~/Desktop`,
  `~/Pictures` and `~/Downloads`, and the apps that keep a setting file say
  which folder they use: the `settings` closure reads it and returns the
  keys, and that folder is watched as well. An app that saves somewhere
  else is covered by "Also watch folders" in the menu.
- **What to take** is the app's own name, followed by a separator —
  `Snipaste 2026-11-06.png`, `Snipaste_2026-11-06.png`, `Snipaste-2026-11-06.png`.
  The separator is part of the name, so `Kap` does not take `Kaplan.jpg`. An
  app that names its files differently says so in `extraPrefixes`; an app
  whose setting file holds its file name pattern says so in `settings`.

A file is taken when its name starts with one of these, so a folder that
holds more than captures only gives up the ones the app took. A folder is
watched once, and every app that is turned on is looked for in it.

macOS asks for permission before a folder can be watched, so the first launch
asks for the Desktop and the Downloads folder. A rebuild is signed afresh, so
it asks again.

## What a folder takes

`ScreenshotWatcher.Acceptance` says what a file has to be for the line to
take it:

- `.anyImage` takes every image. For a folder that holds nothing but captures.
- `.screenCapture(names:)` takes what macOS took, and what a capture app
  wrote: the file carries macOS's tag, or its name is one a capture app gives.
- `.named(prefixes)` takes only the pictures whose name starts with one of
  these.

The Desktop takes `.screenCapture(names:)` with the names of the apps that
are turned on, so a capture saved there hangs even though macOS did not tag
it. Any other folder takes every image.

A new kind of source of images is a new case here, plus the watcher that
feeds it in `AppDelegate.startWatcher()`.

## Turning a capture app off

"Capture apps" in the menu lists the apps that are installed. Turning one off
stops its folders being watched and its files hanging. The choice is kept in
`captureAppsDisabled`, so an app installed later is on without being asked.

## Platforms

Tendedero is a macOS app: it draws a line under the menu bar, takes over the
system screenshot folder, and reads the tag macOS puts on its own
screenshots. Those are macOS things, so the app is macOS only.

The capture app knowledge is not. It is a package of its own,
`TendederoCore`, with no AppKit and no macOS-only API in it: `import
Foundation` and nothing else. It is the part that could be carried to
another system; the watchers and the line would have to be written again.

Two things are not the same on every system, so the host says them
(`CapturePlatform`): where the apps are kept, and where pictures land when
nothing says otherwise. The macOS answers are in
`Sources/Tendedero/CapturePlatform.swift`.

## The core package

```
TendederoCore/
  Package.swift
  Sources/TendederoCore/       the rules
  Sources/CaptureAppsCheck/    the checks
  scripts/check-portable.sh    fails if a macOS-only thing creeps in
```

The app depends on it by path, so the rules are built once and used by the
app:

```swift
dependencies: [.package(path: "TendederoCore")]
```

The package says nothing about platforms, and `check-portable.sh` fails when
a macOS-only import or API is used in it. That is what keeps "it can be
built for another system" true rather than a claim.

## Checking

```sh
swift run --package-path TendederoCore CaptureAppsCheck
bash TendederoCore/scripts/check-portable.sh
swift scripts/check-strings.swift
```

The first checks the reading of the ini files, the names the apps give their
files, and the folders that are watched for them. The second fails when the
core uses something only macOS has. The third checks the eleven languages.
`XCTest` is not part of the Command Line Tools, so the checks are plain
programs that exit non-zero when something is wrong.

## Building

```sh
scripts/build-app.sh release
```

The app is in `build/Tendedero.app`. Quit any other copy first: they share
the same bundle id and the same screenshot settings.
