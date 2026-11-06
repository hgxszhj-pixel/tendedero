import Foundation
import TendederoCore

/// The machine this app runs on: where apps are kept, and where pictures land
/// when nothing says otherwise.
///
/// The rules for the apps that take screenshots live in TendederoCore, which
/// is the same on every system. These two things are not, so they are said
/// here, where macOS is known.
extension CapturePlatform {
    static let macOS: CapturePlatform = {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        let applications = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true),
        ]
        return CapturePlatform(
            isInstalled: { name in
                applications.contains {
                    fm.fileExists(atPath: $0.appendingPathComponent(name + ".app").path)
                }
            },
            standardFolders: ["Desktop", "Pictures", "Downloads"].map {
                home.appendingPathComponent($0, isDirectory: true)
            })
    }()
}
