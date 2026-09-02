import AppKit

struct AppEntry: Identifiable, Hashable {
    let id: URL
    let key: String // bundle id (stable across renames/updates), path fallback
    let name: String
    let icon: NSImage
}

enum AppScanner {
    static let roots = [
        "/Applications",
        "/System/Applications",
        NSHomeDirectory() + "/Applications",
    ]

    // .app bundles at the top level of each root, plus one folder level down
    // (e.g. /Applications/Utilities). Sorted by localized display name.
    static func scan() -> [AppEntry] {
        let fm = FileManager.default
        var urls: [URL] = []

        for root in roots {
            guard let items = try? fm.contentsOfDirectory(
                at: URL(fileURLWithPath: root),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for item in items {
                if item.pathExtension == "app" {
                    urls.append(item)
                } else if (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                    let nested = (try? fm.contentsOfDirectory(
                        at: item,
                        includingPropertiesForKeys: nil,
                        options: [.skipsHiddenFiles]
                    )) ?? []
                    urls.append(contentsOf: nested.filter { $0.pathExtension == "app" })
                }
            }
        }

        var seen = Set<String>()
        return urls
            .filter { seen.insert($0.path).inserted }
            .map { url in
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 128, height: 128)
                return AppEntry(
                    id: url,
                    key: Bundle(url: url)?.bundleIdentifier ?? url.path,
                    name: fm.displayName(atPath: url.path),
                    icon: icon
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
