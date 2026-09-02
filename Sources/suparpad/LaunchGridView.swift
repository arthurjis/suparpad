import SwiftUI
import UniformTypeIdentifiers

// M3: two fixed-7-column sections — curated `top`, dump `bottom` — split by a
// divider bar. Drag-and-drop within and across sections; layout persists.
struct LaunchGridView: View {
    @ObservedObject var model: GridModel
    let onLaunch: (AppEntry) -> Void
    let onDismiss: () -> Void

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 24),
        count: 7
    )

    var body: some View {
        ZStack {
            BlurBackground().ignoresSafeArea()
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss) // background click dismisses

            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    section(model.top, .top)
                    DividerBar()
                    section(model.bottom, .bottom)
                }
                .padding(.horizontal, 120)
                .padding(.vertical, 60)
            }
        }
        // Fallback: a drop that misses every section still ends the drag,
        // so a mid-drag release can never leave an icon hidden.
        .onDrop(of: [.text], delegate: CatchAllDropDelegate(model: model))
    }

    private func section(_ apps: [AppEntry], _ which: GridSection) -> some View {
        LazyVGrid(columns: columns, spacing: 36) {
            ForEach(apps) { app in
                AppIconView(app: app) { onLaunch(app) }
                    // Dragged icon leaves a traveling gap (real Launchpad feel):
                    // the slot reflows but renders empty; only the cursor copy shows.
                    .opacity(model.dragging == app ? 0 : 1)
                    .onDrag {
                        // Hide on the next runloop turn so the drag snapshot
                        // captures the still-visible icon. endDrag is driven by
                        // the drop delegates / Esc / panel-open backstop — NOT a
                        // provider deinit, whose late firing on the *next* drag
                        // would nil `dragging` mid-drag and block cross-section moves.
                        DispatchQueue.main.async { model.dragging = app }
                        return NSItemProvider(object: app.key as NSString)
                    }
                    .onDrop(of: [.text], delegate: ReorderDropDelegate(target: app, model: model))
            }
        }
        // minHeight + contentShape must wrap onDrop so the whole band (even
        // when empty) is a drop target.
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
        .contentShape(Rectangle())
        .onDrop(of: [.text], delegate: SectionDropDelegate(section: which, model: model))
    }
}

// A hovered icon reflows the dragged app into its slot.
private struct ReorderDropDelegate: DropDelegate {
    let target: AppEntry
    let model: GridModel
    func dropEntered(info: DropInfo) {
        if let dragging = model.dragging { model.move(dragging, before: target) }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { model.endDrag(); return true }
}

// Dropping in a section's empty area (or dragging into an empty section)
// appends the app to that section's end.
private struct SectionDropDelegate: DropDelegate {
    let section: GridSection
    let model: GridModel
    func dropEntered(info: DropInfo) {
        if let dragging = model.dragging { model.moveToEnd(dragging, section: section) }
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { model.endDrag(); return true }
}

// Last-resort: a drop landing on no section (divider, outer padding) still
// ends the drag so nothing stays hidden. Keeps the current order.
private struct CatchAllDropDelegate: DropDelegate {
    let model: GridModel
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { model.endDrag(); return true }
}

private struct DividerBar: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(.white.opacity(0.25))
            .frame(height: 3)
            .padding(.horizontal, 40)
    }
}

struct BlurBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .hudWindow
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

private struct AppIconView: View {
    let app: AppEntry
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 84, height: 84)
                .scaleEffect(hovering ? 1.08 : 1.0)
                .animation(.easeOut(duration: 0.12), value: hovering)
            Text(app.name)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(width: 130)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .onHover { hovering = $0 }
    }
}
