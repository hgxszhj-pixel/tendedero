import Foundation

/// Other apps that take screenshots and write the pictures themselves.
///
/// macOS tags the files it takes with an extended attribute, so Tendedero can
/// tell its own screenshots apart from anything else on the Desktop. These
/// apps write their own files without that tag, so Tendedero has to learn
/// where they save them and what they call them. Otherwise their captures
/// never reach the line.
struct CaptureApp {
    /// A short name, to remember whether the user turned it on.
    let id: String
    /// The name the app is known by, shown in the menu.
    let name: String
    /// The folders the app saves to. Only the ones that exist are watched.
    let folders: [URL]
    /// The names the app gives its files, so they can be told apart from
    /// other pictures in a folder that holds more than screenshots.
    let prefixes: [String]
}

enum CaptureApps {
    private static let disabledKey = "captureAppsDisabled"

    // MARK: What Tendedero knows about each app

    /// One capture app, and how to find it.
    private struct Known {
        let id: String
        /// The name shown in the menu.
        let name: String
        /// The bundle names to look for, newest first.
        let appNames: [String]
        /// Where the app saves by default.
        let folders: [URL]
        /// The names it gives its files.
        let prefixes: [String]
        /// Reads the app's own settings, when they are kept where we know.
        let settings: () -> [String: String]
    }

    private static func pictures(_ name: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }

    private static let known: [Known] = [
        Known(id: "snipaste", name: "Snipaste",
              appNames: ["Snipaste"],
              folders: [pictures("Snipaste")],
              prefixes: ["Snipaste_"],
              settings: snipasteSettings),
        Known(id: "cleanshot", name: "CleanShot X",
              appNames: ["CleanShot X", "CleanShot"],
              folders: [pictures("CleanShot X")],
              prefixes: ["CleanShot"],
              settings: { [String: String]() }),
        Known(id: "shottr", name: "Shottr",
              appNames: ["Shottr"],
              folders: [pictures("Shottr")],
              prefixes: ["Shottr"],
              settings: { [String: String]() }),
        Known(id: "pixpin", name: "PixPin",
              appNames: ["PixPin"],
              folders: [pictures("PixPin")],
              prefixes: ["PixPin"],
              settings: { [String: String]() }),
        Known(id: "kap", name: "Kap",
              appNames: ["Kap"],
              folders: [pictures("Kap")],
              prefixes: ["Screen Shot"],
              settings: { [String: String]() }),
    ]

    // MARK: Finding the apps

    /// The apps that are installed on this Mac, with the folders and the file
    /// names they use.
    static func installed() -> [CaptureApp] {
        known.compactMap { app -> CaptureApp? in
            guard app.appNames.contains(where: isInstalled) else { return nil }
            var folders = app.folders
            var prefixes = app.prefixes
            let settings = app.settings()
            if let folder = settings["last_save_folder"], !folder.isEmpty {
                folders.append(folderURL(folder))
            }
            if let path = settings["quick_save_path"], !path.isEmpty {
                let expanded = (path as NSString).expandingTildeInPath
                folders.append(URL(fileURLWithPath: expanded).deletingLastPathComponent())
                if let prefix = patternPrefix(URL(fileURLWithPath: expanded).lastPathComponent) {
                    prefixes.append(prefix)
                }
            }
            if let pattern = settings["file_name_pattern"], let prefix = patternPrefix(pattern) {
                prefixes.append(prefix)
            }
            return CaptureApp(
                id: app.id,
                name: app.name,
                folders: unique(folders).filter(isFolder),
                prefixes: unique(prefixes))
        }
    }

    /// The apps that are installed and that the user wants.
    static func enabled() -> [CaptureApp] {
        let off = Set(disabledIDs)
        return installed().filter { !off.contains($0.id) }
    }

    /// The names the capture apps that are turned on give their files.
    static var enabledPrefixes: [String] {
        enabled().flatMap(\.prefixes)
    }

    /// The apps the user turned off. Every app that is installed is on until
    /// the user turns one off, so an app installed later is on as well.
    static var disabledIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: disabledKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: disabledKey) }
    }

    /// Whether a capture app is turned on.
    static func isEnabled(_ id: String) -> Bool {
        !disabledIDs.contains(id)
    }

    /// Turns a capture app on or off.
    static func setEnabled(_ id: String, _ on: Bool) {
        var off = disabledIDs
        if on {
            off.removeAll { $0 == id }
        } else if !off.contains(id) {
            off.append(id)
        }
        disabledIDs = off
    }

    /// Whether a file name is one a capture app gave.
    static func matches(_ name: String, prefixes: Set<String>) -> Bool {
        prefixes.contains { name.hasPrefix($0) }
    }

    // MARK: Reading what the apps say

    /// Whether an app with this bundle name is installed.
    private static func isInstalled(_ appName: String) -> Bool {
        let fm = FileManager.default
        for directory in ["/Applications", fm.homeDirectoryForCurrentUser.path + "/Applications"] {
            if fm.fileExists(atPath: directory + "/" + appName + ".app") { return true }
        }
        return false
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
    static func parseIni(_ text: String) -> [String: String] {
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
    static func patternPrefix(_ pattern: String) -> String? {
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
