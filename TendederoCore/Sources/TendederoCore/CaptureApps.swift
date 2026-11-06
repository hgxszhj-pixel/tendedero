import Foundation

/// What Tendedero knows about the apps that take screenshots.
///
/// The rules are the same on every system. The two things that are not — where
/// apps are kept, and where pictures land when nothing says otherwise — are
/// given by the host (see `CapturePlatform`).
public enum CaptureApps {
    private static let disabledKey = "captureAppsDisabled"

    // MARK: What Tendedero knows about each app

    /// One capture app, and how to find it.
    private struct Known {
        let id: String
        /// The name shown in the menu.
        let name: String
        /// The bundle names to look for, newest first.
        let appNames: [String]
        /// The names it gives its files that are not its own name.
        let extraPrefixes: [String]
        /// Reads the app's own settings, when they are kept where we know.
        let settings: () -> [String: String]
    }

    private static let known: [Known] = [
        Known(id: "snipaste", name: "Snipaste", appNames: ["Snipaste"],
              extraPrefixes: [], settings: snipasteSettings),
        Known(id: "cleanshot", name: "CleanShot X", appNames: ["CleanShot X", "CleanShot"],
              extraPrefixes: ["CleanShot "], settings: { [String: String]() }),
        Known(id: "shottr", name: "Shottr", appNames: ["Shottr"],
              extraPrefixes: [], settings: { [String: String]() }),
        Known(id: "pixpin", name: "PixPin", appNames: ["PixPin"],
              extraPrefixes: [], settings: { [String: String]() }),
        Known(id: "kap", name: "Kap", appNames: ["Kap"],
              extraPrefixes: ["Screen Shot "], settings: { [String: String]() }),
        Known(id: "monosnap", name: "Monosnap", appNames: ["Monosnap"],
              extraPrefixes: [], settings: { [String: String]() }),
        Known(id: "lightshot", name: "Lightshot", appNames: ["Lightshot"],
              extraPrefixes: [], settings: { [String: String]() }),
    ]

    // MARK: Finding the apps

    /// The apps that are installed on this machine, with the folders and the
    /// file names they use.
    public static func installed(in platform: CapturePlatform) -> [CaptureApp] {
        known.compactMap { app -> CaptureApp? in
            guard app.appNames.contains(where: platform.isInstalled) else { return nil }
            let settings = app.settings()
            return CaptureApp(
                id: app.id,
                name: app.name,
                folders: unique(folders(settings: settings, in: platform)).filter(isFolder),
                prefixes: unique(prefixes(name: app.name,
                                         extra: app.extraPrefixes,
                                         settings: settings)))
        }
    }

    /// The apps that are installed and that the user wants.
    public static func enabled(in platform: CapturePlatform) -> [CaptureApp] {
        let off = Set(disabledIDs)
        return installed(in: platform).filter { !off.contains($0.id) }
    }

    /// The names the capture apps that are turned on give their files.
    public static func enabledPrefixes(in platform: CapturePlatform) -> [String] {
        enabled(in: platform).flatMap(\.prefixes)
    }

    /// The apps the user turned off. Every app that is installed is on until
    /// the user turns one off, so an app installed later is on as well.
    public static var disabledIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: disabledKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: disabledKey) }
    }

    /// Whether a capture app is turned on.
    public static func isEnabled(_ id: String) -> Bool {
        !disabledIDs.contains(id)
    }

    /// Turns a capture app on or off.
    public static func setEnabled(_ id: String, _ on: Bool) {
        var off = disabledIDs
        if on {
            off.removeAll { $0 == id }
        } else if !off.contains(id) {
            off.append(id)
        }
        disabledIDs = off
    }

    /// Whether a file name is one a capture app gave.
    public static func matches(_ name: String, prefixes: Set<String>) -> Bool {
        prefixes.contains { name.hasPrefix($0) }
    }

    // MARK: Where to look

    /// The folders an app's pictures may be in: the ones pictures land in
    /// anyway, and the ones its settings name.
    public static func folders(settings: [String: String], in platform: CapturePlatform) -> [URL] {
        var folders = platform.standardFolders
        if let folder = settings["last_save_folder"], !folder.isEmpty {
            folders.append(folderURL(folder))
        }
        if let path = settings["quick_save_path"], !path.isEmpty {
            let expanded = (path as NSString).expandingTildeInPath
            folders.append(URL(fileURLWithPath: expanded).deletingLastPathComponent())
        }
        return unique(folders)
    }

    /// The folders to watch for pictures that other apps took, and the names
    /// to take there. A folder is watched once, and every app that is turned
    /// on is looked for in it.
    public static func watchPlan(in platform: CapturePlatform) -> [(folder: URL, prefixes: Set<String>)] {
        watchPlan(for: enabled(in: platform))
    }

    /// The same, for the given apps.
    public static func watchPlan(for apps: [CaptureApp]) -> [(folder: URL, prefixes: Set<String>)] {
        var byPath: [String: (folder: URL, prefixes: Set<String>)] = [:]
        for app in apps {
            for folder in app.folders {
                let key = folder.standardizedFileURL.path
                var entry = byPath[key] ?? (folder: folder, prefixes: [])
                entry.prefixes.formUnion(app.prefixes)
                byPath[key] = entry
            }
        }
        return byPath.values.sorted { $0.folder.path < $1.folder.path }
    }

    // MARK: Reading what the apps say

    /// The names an app gives its files: the ones it names after itself, the
    /// ones it keeps its own way, and what its settings say.
    public static func prefixes(name: String, extra: [String], settings: [String: String]) -> [String] {
        var prefixes = namedPrefixes(name) + extra
        if let path = settings["quick_save_path"], !path.isEmpty {
            let expanded = (path as NSString).expandingTildeInPath
            if let prefix = patternPrefix(URL(fileURLWithPath: expanded).lastPathComponent) {
                prefixes.append(prefix)
            }
        }
        if let pattern = settings["file_name_pattern"], let prefix = patternPrefix(pattern) {
            prefixes.append(prefix)
        }
        return unique(prefixes)
    }

    /// The names an app gives its files when it names them after itself:
    /// `Snipaste 2026-11-06.png`, `Snipaste_2026-11-06.png`. The separator is
    /// part of the name, so `Kap` does not take `Kaplan.jpg`.
    public static func namedPrefixes(_ name: String) -> [String] {
        [" ", "_", "-"].map { name + $0 }
    }

    /// Snipaste keeps its settings in an ini file in the home folder.
    private static func snipasteSettings() -> [String: String] {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".snipaste/config.ini").path
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return [:] }
        return parseIni(text)
    }

    /// Reads an ini file: lines of `key=value` under `[Section]` headers. Only
    /// the keys are kept; the section a key is in makes no difference here.
    public static func parseIni(_ text: String) -> [String: String] {
        var values: [String: String] = [:]
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = line.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("[") || line.hasPrefix(";") || line.hasPrefix("#") { continue }
            guard let equals = line.firstIndex(of: "=") else { continue }
            let key = String(line[line.startIndex..<equals]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: equals)...]).trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            values[key] = value
        }
        return values
    }

    /// The fixed part of a file name pattern: what comes before the first
    /// `$`. Snipaste writes `Snipaste_$yyyy-MM-dd_HH-mm-ss$.jpg`, so the
    /// name of its files starts with `Snipaste_`.
    public static func patternPrefix(_ pattern: String) -> String? {
        let parts = pattern.split(separator: "$", maxSplits: 1, omittingEmptySubsequences: false)
        let head = parts.first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
        return head.isEmpty ? nil : head
    }

    // MARK: Small helpers

    private static func folderURL(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
    }

    private static func isFolder(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func unique(_ urls: [URL]) -> [URL] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    private static func unique(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }
}
