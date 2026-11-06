// Checks the reading of the capture apps: the ini file Snipaste keeps its
// settings in, and the names it gives its files.
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

        // A file belongs to a capture app when its name starts with the name
        // that app gives its files.
        expect(CaptureApps.matches("Snipaste_2026-11-06_14-39-00.jpg", prefixes: ["Snipaste_"]), true, "match: Snipaste file")
        expect(CaptureApps.matches("Screenshot 2026-11-06.jpg", prefixes: ["Snipaste_"]), false, "match: other file")
        expect(CaptureApps.matches("CleanShot 2026-11-06 at 14.39.00.png", prefixes: ["CleanShot"]), true, "match: CleanShot file")
        expect(CaptureApps.matches("Snipaste_2026-11-06_14-39-00.jpg", prefixes: []), false, "match: nothing to match")

        if failures.isEmpty {
            print("capture apps: ok")
        } else {
            failures.forEach { print("failure: \($0)") }
            exit(1)
        }
    }
}
