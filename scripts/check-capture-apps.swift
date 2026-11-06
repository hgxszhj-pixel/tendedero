// Checks the reading of the capture apps: the ini file Snipaste keeps its
// settings in, the names the apps give their files, and the folders that
// are watched for them.
// Usage: swiftc -parse-as-library Sources/Tendedero/CaptureApps.swift \
//            scripts/check-capture-apps.swift -o /tmp/check-capture-apps \
//            && /tmp/check-capture-apps
import Foundation

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

        // Pictures land in the usual folders.
        let home = FileManager.default.homeDirectoryForCurrentUser
        expect(CaptureApps.standardFolders.map(\.lastPathComponent),
               ["Desktop", "Pictures", "Downloads"], "folders: where pictures land")

        // An app's own settings say which folder it uses, on top of those.
        let folders = CaptureApps.folders(settings: ["last_save_folder": "/Users/someone/Pictures"])
        expect(folders.count, 4, "folders: the usual ones and the one the settings name")
        expectContains(folders.map(\.path), home.appendingPathComponent("Pictures").path,
                       "folders: the usual ones are there")
        expectContains(folders.map(\.path), "/Users/someone/Pictures",
                       "folders: the one the settings name is there")

        // A folder is watched once, and every app that is turned on is looked
        // for in it.
        let pictures = URL(fileURLWithPath: "/Users/someone/Pictures", isDirectory: true)
        let desktop = URL(fileURLWithPath: "/Users/someone/Desktop", isDirectory: true)
        let plan = CaptureApps.watchPlan(for: [
            CaptureApp(id: "a", name: "A", folders: [pictures], prefixes: ["A_"]),
            CaptureApp(id: "b", name: "B", folders: [pictures, desktop], prefixes: ["B_"]),
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
