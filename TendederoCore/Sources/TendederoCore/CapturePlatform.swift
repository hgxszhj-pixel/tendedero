import Foundation

/// What is different on the machine the app runs on.
///
/// The rules in `CaptureApps` are the same everywhere: which apps take
/// screenshots, what they call their files, and how the folders to watch are
/// put together. Where the apps are kept and where pictures land are not the
/// same on every system, so the host says so.
public struct CapturePlatform {
    /// Whether an app with this bundle name is installed.
    public var isInstalled: (String) -> Bool
    /// The folders where pictures land when nothing says otherwise.
    public var standardFolders: [URL]

    public init(isInstalled: @escaping (String) -> Bool, standardFolders: [URL]) {
        self.isInstalled = isInstalled
        self.standardFolders = standardFolders
    }
}
