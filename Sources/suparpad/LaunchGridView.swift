import SwiftUI
import UniformTypeIdentifiers

// M3: fixed 7-column grid (like classic Launchpad — spatial memory needs a
// stable column count), drag-and-drop reordering with live reflow.
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
                LazyVGrid(columns: columns, spacing: 36) {
                    ForEach(model.apps) { app in
                        AppIconView(app: app) { onLaunch(app) }
                            // The dragged icon leaves a traveling gap (real
                            // Launchpad style): the slot reflows but renders
                            // empty; the cursor snapshot is the only copy.
                            .opacity(model.dragging == app ? 0 : 1)
                            .onDrag {
                                let provider = DragSessionProvider(object: app.key as NSString)
                                provider.onSessionEnd = {
                                    DispatchQueue.main.async {
                                        MainActor.assumeIsolated { model.endDrag() }
                                    }
                                }
                                // Hide on the next runloop turn so the drag
                                // snapshot is taken while still visible.
                                DispatchQueue.main.async { model.dragging = app }
                                return provider
                            }
                            .onDrop(
                                of: [.text],
                                delegate: ReorderDropDelegate(target: app, model: model)
                            )
                    }
                }
                .padding(.horizontal, 120)
                .padding(.vertical, 80)
            }
            .onDrop(of: [.text], delegate: EndDragDropDelegate(model: model))
        }
    }
}

// NSItemProvider is released by AppKit when the drag session ends — drop,
// cancel, or Esc alike — making its deinit the one reliable "drag over"
// signal SwiftUI doesn't expose. Used to un-hide the gap icon.
private final class DragSessionProvider: NSItemProvider, @unchecked Sendable {
    var onSessionEnd: (() -> Void)?
    deinit { onSessionEnd?() }
}

// Sliding reflow: entering another icon's area moves the dragged app there.
private struct ReorderDropDelegate: DropDelegate {
    let target: AppEntry
    let model: GridModel

    func dropEntered(info: DropInfo) {
        guard let dragging = model.dragging else { return }
        model.move(dragging, before: target)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        model.endDrag()
        return true
    }
}

// Drop outside any icon (background/scroll area): keep the current order.
private struct EndDragDropDelegate: DropDelegate {
    let model: GridModel

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        model.endDrag()
        return true
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
