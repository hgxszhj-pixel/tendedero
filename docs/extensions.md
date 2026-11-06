# Extending Tendedero

Tendedero watches folders and hangs what it finds there. Most extensions are
a few lines in one place, and this is where they go.

## Another screenshot app

macOS tags the files it takes with an extended attribute, so Tendedero can
tell its own screenshots apart from anything else on the Desktop. Other apps
write their own files without that tag, so they are found by the folder they
save to and by the names they give their files.

`Sources/Tendedero/CaptureApps.swift` holds what Tendedero knows about them.
Each app is one entry in `CaptureApps.known`:

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

The capture app knowledge is not: `CaptureApps.swift` is Foundation alone,
with no AppKit and no macOS-only API. It is the part that could be carried
to another platform; the watchers and the line would have to be written
again.

## Checking

```sh
swiftc -parse-as-library Sources/Tendedero/CaptureApps.swift \
    scripts/check-capture-apps.swift -o /tmp/tendedero-capture-check
/tmp/tendedero-capture-check
swift scripts/check-strings.swift
```

The first checks the reading of the ini files, the names the apps give their
files, and the folders that are watched for them. The second checks the
eleven languages. `XCTest` is not part of the Command Line Tools, so the
checks are plain scripts that exit non-zero when something is wrong.

## Building

```sh
scripts/build-app.sh release
```

The app is in `build/Tendedero.app`. Quit any other copy first: they share
the same bundle id and the same screenshot settings.
