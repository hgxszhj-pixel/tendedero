import Foundation

/// Another app that takes screenshots and writes the pictures itself.
///
/// macOS tags the files it takes with an extended attribute, so Tendedero can
/// tell its own screenshots apart from anything else on the Desktop. These
/// apps write their own files without that tag, so Tendedero has to learn
/// what they call their files. Where they keep their pictures is known:
/// pictures land in the usual folders, and the apps that keep a setting
/// file say which folder they use.
public struct CaptureApp {
    /// A short name, to remember whether the user turned it on.
    public let id: String
    /// The name the app is known by, shown in the menu.
    public let name: String
    /// The folders its pictures may be in.
    public let folders: [URL]
    /// The names it gives its files, so they can be told apart from other
    /// pictures in a folder that holds more than screenshots.
    public let prefixes: [String]

    public init(id: String, name: String, folders: [URL], prefixes: [String]) {
        self.id = id
        self.name = name
        self.folders = folders
        self.prefixes = prefixes
    }
}
