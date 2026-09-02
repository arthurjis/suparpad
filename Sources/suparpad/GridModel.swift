import AppKit
import SwiftUI

enum GridSection { case top, bottom }

// Two ordered sections: `top` for apps you actually use, `bottom` as the dump.
// An app lives in exactly one section. New apps land in the dump; you promote
// the keepers by dragging them up. Persisted to layout.json.
@MainActor
final class GridModel: ObservableObject {
    @Published var top: [AppEntry] = []
    @Published var bottom: [AppEntry] = []
    @Published var dragging: AppEntry? // in-grid icon hides while in hand

    private struct Layout: Codable { var top: [String]; var bottom: [String] }

    private let layoutURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("suparpad", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("layout.json")
    }()

    func load() {
        let scanned = AppScanner.scan() // alphabetical
        let byKey = Dictionary(scanned.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })

        var topKeys: [String] = [], bottomKeys: [String] = []
        if let data = try? Data(contentsOf: layoutURL) {
            if let saved = try? JSONDecoder().decode(Layout.self, from: data) {
                topKeys = saved.top; bottomKeys = saved.bottom
            } else if let flat = try? JSONDecoder().decode([String].self, from: data) {
                bottomKeys = flat // migrate old single-list layout into the dump;
                                  // top starts empty so the divider is visible
            }
        }

        // Assign each scanned app to exactly one section; new apps to the dump.
        var placed = Set<String>()
        func take(_ keys: [String]) -> [AppEntry] {
            keys.compactMap { key in
                guard !placed.contains(key), let entry = byKey[key] else { return nil }
                placed.insert(key)
                return entry
            }
        }
        top = take(topKeys)
        bottom = take(bottomKeys)
        bottom.append(contentsOf: scanned.filter { !placed.contains($0.key) })

        persist() // prune removed apps, adopt fresh ones
    }

    private func removeItem(_ item: AppEntry) {
        if let i = top.firstIndex(of: item) { top.remove(at: i) }
        else if let i = bottom.firstIndex(of: item) { bottom.remove(at: i) }
    }

    private func section(of item: AppEntry) -> GridSection? {
        if top.contains(item) { return .top }
        if bottom.contains(item) { return .bottom }
        return nil
    }

    // Reflow: place `item` where `target` currently sits (either section).
    func move(_ item: AppEntry, before target: AppEntry) {
        guard item != target else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            removeItem(item)
            if let i = top.firstIndex(of: target) { top.insert(item, at: i) }
            else if let i = bottom.firstIndex(of: target) { bottom.insert(item, at: i) }
        }
    }

    // Drop into a section's empty area: append to that section's end.
    func moveToEnd(_ item: AppEntry, section: GridSection) {
        guard self.section(of: item) != section || indexIsNotLast(item, section) else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            removeItem(item)
            switch section {
            case .top: top.append(item)
            case .bottom: bottom.append(item)
            }
        }
    }

    private func indexIsNotLast(_ item: AppEntry, _ section: GridSection) -> Bool {
        switch section {
        case .top: return top.last != item
        case .bottom: return bottom.last != item
        }
    }

    // Idempotent: called from performDrop AND the drag session's release
    // (the only signal that fires on cancelled drags too) AND on panel open.
    func endDrag() {
        guard dragging != nil else { return }
        dragging = nil
        persist()
    }

    func persist() {
        let layout = Layout(top: top.map(\.key), bottom: bottom.map(\.key))
        guard let data = try? JSONEncoder().encode(layout) else { return }
        try? data.write(to: layoutURL, options: .atomic)
    }
}
