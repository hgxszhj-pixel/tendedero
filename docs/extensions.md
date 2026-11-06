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
| `folders` | where the app saves by default |
| `prefixes` | the names the app gives its files |
| `settings` | reads the app's own settings, when they are kept where we know |

Adding an app is one entry. When it keeps its settings in a file we know, the
`settings` closure reads it and returns the keys, and the folder it saves to
and the names it gives its files come from there, so the app needs no
setting up by hand.

A file is taken when its name starts with one of the app's `prefixes`, so a
folder that holds more than captures only gives up the ones the app took.

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

## Checking

```sh
swiftc -parse-as-library Sources/Tendedero/CaptureApps.swift \
    scripts/check-capture-apps.swift -o /tmp/tendedero-capture-check
/tmp/tendedero-capture-check
swift scripts/check-strings.swift
```

The first checks the reading of the ini files and the names the apps give
their files. The second checks the eleven languages. `XCTest` is not part of
the Command Line Tools, so the checks are plain scripts that exit non-zero
when something is wrong.

## Building

```sh
scripts/build-app.sh release
```

The app is in `build/Tendedero.app`. Quit any other copy first: they share
the same bundle id and the same screenshot settings.
