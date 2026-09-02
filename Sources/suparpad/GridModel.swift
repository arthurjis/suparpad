import AppKit
import SwiftUI

// Ordered app list with persistence: saved order first, new apps appended.
@MainActor
final class GridModel: ObservableObject {
    @Published var apps: [AppEntry] = []
    var dragging: AppEntry?

    private let layoutURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("suparpad", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("layout.json")
    }()

    func load() {
        let scanned = AppScanner.scan() // alphabetical
        let savedOrder = (try? JSONDecoder().decode(
            [String].self, from: Data(contentsOf: layoutURL))) ?? []
        let rank = Dictionary(uniqueKeysWithValues: savedOrder.enumerated().map { ($1, $0) })

        // Known apps by saved rank, new apps appended (already alphabetical).
        let known = scanned.filter { rank[$0.key] != nil }
            .sorted { rank[$0.key]! < rank[$1.key]! }
        let fresh = scanned.filter { rank[$0.key] == nil }
        apps = known + fresh

        if apps.map(\.key) != savedOrder { persist() } // prune removed, adopt fresh
    }

    func move(_ item: AppEntry, before target: AppEntry) {
        guard item != target,
              let from = apps.firstIndex(of: item),
              let to = apps.firstIndex(of: target) else { return }
        withAnimation(.easeInOut(duration: 0.18)) {
            apps.move(
                fromOffsets: IndexSet(integer: from),
                toOffset: to > from ? to + 1 : to
            )
        }
    }

    func persist() {
        guard let data = try? JSONEncoder().encode(apps.map(\.key)) else { return }
        try? data.write(to: layoutURL, options: .atomic)
    }
}
