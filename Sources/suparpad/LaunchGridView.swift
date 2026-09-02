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
                        .frame(minHeight: 150) // stays droppable when empty
                    DividerBar()
                    section(model.bottom, .bottom)
                        .frame(minHeight: 150)
                }
                .padding(.horizontal, 120)
                .padding(.vertical, 60)
            }
        }
    }

    private func section(_ apps: [AppEntry], _ which: GridSection) -> some View {
        LazyVGrid(columns: columns, spacing: 36) {
            ForEach(apps) { app in
                AppIconView(app: app) { onLaunch(app) }
                    // Dragged icon leaves a traveling gap (real Launchpad feel):
                    // the slot reflows but renders empty; only the cursor copy shows.
                    .opacity(model.dragging == app ? 0 : 1)
                    .onDrag {
                        let provider = DragSessionProvider(object: app.key as NSString)
                        provider.onSessionEnd = {
                            DispatchQueue.main.async { MainActor.assumeIsolated { model.endDrag() } }
                        }
                        DispatchQueue.main.async { model.dragging = app } // hide next turn
                        return provider
                    }
                    .onDrop(of: [.text], delegate: ReorderDropDelegate(target: app, model: model))
            }
        }
        .frame(maxWidth: .infinity)
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

// NSItemProvider is released when the drag session ends — drop, cancel, or Esc
// alike — making its deinit the one reliable "drag over" signal SwiftUI omits.
private final class DragSessionProvider: NSItemProvider, @unchecked Sendable {
    var onSessionEnd: (() -> Void)?
    deinit { onSessionEnd?() }
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
