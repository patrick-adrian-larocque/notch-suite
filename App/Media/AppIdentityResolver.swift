import AppKit
import NotchCore

/// An application's name and icon for display, looked up from an `AppIdentity`.
///
/// Every field but `identity` is optional: looking an application up can fail, and a
/// session without a name or icon is still a session.
struct ResolvedAppIdentity {
    /// The identity this was resolved from, unchanged.
    let identity: AppIdentity
    /// The bundle identifier, from the identity or from the running process.
    let bundleIdentifier: String?
    /// The application's localized name.
    let displayName: String?
    /// The application's icon.
    let icon: NSImage?
}

/// Looks up an `AppIdentity` in the running applications and the installed ones.
///
/// It only reads system state and never changes it. Calls are cheap, so it keeps no
/// cache; call it when the identity changes.
@MainActor
struct AppIdentityResolver {
    /// Resolves `identity` as well as it can.
    ///
    /// The process identifier is tried first. Its process is used only while it is still
    /// running and, when the identity also has a bundle identifier, only when the two
    /// agree: the system reuses process identifiers, so a different bundle means the
    /// original process exited. Then the bundle identifier is tried against the installed
    /// applications. When neither works, only what the identity carries is returned.
    func resolve(_ identity: AppIdentity) -> ResolvedAppIdentity {
        if let app = runningApplication(for: identity) {
            return ResolvedAppIdentity(
                identity: identity,
                bundleIdentifier: app.bundleIdentifier ?? identity.bundleIdentifier,
                displayName: app.localizedName,
                icon: app.icon)
        }
        if let bundleIdentifier = identity.bundleIdentifier,
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        {
            return ResolvedAppIdentity(
                identity: identity,
                bundleIdentifier: bundleIdentifier,
                displayName: Self.displayName(ofApplicationAt: url),
                icon: NSWorkspace.shared.icon(forFile: url.path))
        }
        return ResolvedAppIdentity(
            identity: identity, bundleIdentifier: identity.bundleIdentifier, displayName: nil,
            icon: nil)
    }

    /// The running process `identity` names, or `nil` when it exited or its process
    /// identifier now belongs to another application.
    private func runningApplication(for identity: AppIdentity) -> NSRunningApplication? {
        guard let processIdentifier = identity.processIdentifier,
            let app = NSRunningApplication(processIdentifier: processIdentifier),
            !app.isTerminated
        else {
            return nil
        }
        if let expected = identity.bundleIdentifier, app.bundleIdentifier != expected {
            return nil
        }
        return app
    }

    /// The installed application's localized name, from its bundle when it has one.
    private static func displayName(ofApplicationAt url: URL) -> String {
        let bundle = Bundle(url: url)
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            if let name = bundle?.object(forInfoDictionaryKey: key) as? String, !name.isEmpty {
                return name
            }
        }
        return url.deletingPathExtension().lastPathComponent
    }
}
