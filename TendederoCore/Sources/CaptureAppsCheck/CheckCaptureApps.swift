// Checks the rules for the apps that take screenshots: the ini file Snipaste
// keeps its settings in, the names the apps give their files, and the folders
// that are watched for them.
//
// Usage: swift run --package-path TendederoCore CaptureAppsCheck
import Foundation
import TendederoCore

@main
struct CheckCaptureApps {
    static func main() {
        var failures: [String] = []

        func expect<T: Equatable>(_ actual: T, _ wanted: T, _ what: String) {
            if actual != wanted {
                failures.append("\(what): got \(actual), wanted \(wanted)")
            }
        }

        func expectContains<T: Equatable>(_ haystack: [T], _ needle: T, _ what: String) {
            if !haystack.contains(needle) {
                failures.append("\(what): \(needle) not in \(haystack)")
            }
        }

        // An ini file: sections, comments, and keys with values.
        let ini = """
        [General]
        first_run=false
        ; a comment
        # another comment

        [Output]
        last_save_folder=/Users/someone/Pictures
        file_name_pattern=Snipaste_$yyyy-MM-dd_HH-mm-ss$.jpg
        quick_save_path = /Users/someone/Desktop/Snipaste_$yyyy$.jpg
        """
        let values = CaptureApps.parseIni(ini)
        expect(values["last_save_folder"], "/Users/someone/Pictures", "ini: last_save_folder")
        expect(values["file_name_pattern"], "Snipaste_$yyyy-MM-dd_HH-mm-ss$.jpg", "ini: file_name_pattern")
        expect(values["quick_save_path"], "/Users/someone/Desktop/Snipaste_$yyyy$.jpg", "ini: value is trimmed")
        expect(values["first_run"], "false", "ini: first_run")
        expect(values["General"], nil, "ini: section header is not a key")
        expect(values.count, 4, "ini: number of keys")

        // The fixed part of a file name pattern is what comes before the first
        // `$`; a pattern that starts with one has no fixed part.
        expect(CaptureApps.patternPrefix("Snipaste_$yyyy-MM-dd_HH-mm-ss$.jpg"), "Snipaste_", "pattern: fixed part")
        expect(CaptureApps.patternPrefix("$yyyy-MM-dd$.png"), nil, "pattern: no fixed part")
        expect(CaptureApps.patternPrefix("shot.png"), "shot.png", "pattern: no marker at all")

        // An app names its files after itself, with a separator between the
        // name and the rest.
        expect(CaptureApps.namedPrefixes("Kap"), ["Kap ", "Kap_", "Kap-"], "names: after the app's own name")

        // The names an app gives its files: its own, the ones it keeps its
        // own way, and what its settings say. The name the settings give
        // differs from the app's own name, so the two are told apart.
        expect(CaptureApps.prefixes(name: "Snipaste", extra: [],
                                    settings: ["file_name_pattern": "snap_$yyyy$.jpg"]),
               ["Snipaste ", "Snipaste_", "Snipaste-", "snap_"], "names: the app's own name and its settings")
        expect(CaptureApps.prefixes(name: "Kap", extra: ["Screen Shot "], settings: [:]),
               ["Kap ", "Kap_", "Kap-", "Screen Shot "], "names: the app's own way")
        expect(CaptureApps.prefixes(name: "Shottr", extra: [],
                                    settings: ["quick_save_path": "/Users/someone/Desktop/Shottr_$yyyy$.png"]),
               ["Shottr ", "Shottr_", "Shottr-"], "names: what the settings name")

        // A file belongs to a capture app when its name starts with the name
        // that app gives its files.
        expect(CaptureApps.matches("Snipaste_2026-11-06_14-39-00.jpg", prefixes: ["Snipaste_"]), true, "match: Snipaste file")
        expect(CaptureApps.matches("Screenshot 2026-11-06.jpg", prefixes: ["Snipaste_"]), false, "match: other file")
        expect(CaptureApps.matches("CleanShot 2026-11-06 at 14.39.00.png", prefixes: ["CleanShot"]), true, "match: CleanShot file")
        expect(CaptureApps.matches("Snipaste_2026-11-06_14-39-00.jpg", prefixes: []), false, "match: nothing to match")

        // The machine the app runs on: where apps are kept, and where
        // pictures land when nothing says otherwise. The folders are made
        // here, so the check works on any system.
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("tendedero-capture-check", isDirectory: true)
        try? fm.removeItem(at: root)
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let desktop = root.appendingPathComponent("Desktop", isDirectory: true)
        let pictures = root.appendingPathComponent("Pictures", isDirectory: true)
        try? fm.createDirectory(at: desktop, withIntermediateDirectories: true)
        try? fm.createDirectory(at: pictures, withIntermediateDirectories: true)
        let platform = CapturePlatform(isInstalled: { $0 == "Snipaste" },
                                       standardFolders: [desktop, pictures])

        // The apps that are installed are the ones the machine says are.
        expect(CaptureApps.installed(in: platform).map(\.id), ["snipaste"], "apps: the ones the machine says are")
        expectContains(CaptureApps.installed(in: platform).first?.prefixes ?? [],
                       "Snipaste ", "apps: the names they give their files")

        // The folders to watch: the ones pictures land in, and the ones the
        // app's own settings name.
        let usual = CaptureApps.folders(settings: [:], in: platform)
        expect(usual.map(\.standardizedFileURL.path),
               [desktop, pictures].map(\.standardizedFileURL.path), "folders: where pictures land")
        let folders = CaptureApps.folders(settings: ["last_save_folder": "/Users/someone/Pictures"], in: platform)
        expect(folders.count, 3, "folders: the usual ones and the one the settings name")
        expectContains(folders.map(\.path), desktop.path, "folders: the usual ones are there")
        expectContains(folders.map(\.path), "/Users/someone/Pictures",
                       "folders: the one the settings name is there")

        // A folder is watched once, and every app that is turned on is looked
        // for in it.
        let other = URL(fileURLWithPath: "/Users/someone/Desktop", isDirectory: true)
        let plan = CaptureApps.watchPlan(for: [
            CaptureApp(id: "a", name: "A", folders: [pictures], prefixes: ["A_"]),
            CaptureApp(id: "b", name: "B", folders: [pictures, other], prefixes: ["B_"]),
        ])
        expect(plan.count, 2, "plan: one entry per folder")
        let pictureEntry = plan.first { $0.folder.standardizedFileURL.path == pictures.standardizedFileURL.path }
        expect(pictureEntry?.prefixes, ["A_", "B_"], "plan: both apps are looked for in the folder")

        if failures.isEmpty {
            print("capture apps: ok")
        } else {
            failures.forEach { print("failure: \($0)") }
            exit(1)
        }
    }
}
