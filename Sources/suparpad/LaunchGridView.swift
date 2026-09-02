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
                            .onDrag {
                                model.dragging = app
                                return NSItemProvider(object: app.key as NSString)
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
        model.dragging = nil
        model.persist()
        return true
    }
}

// Drop outside any icon (background/scroll area): keep the current order.
private struct EndDragDropDelegate: DropDelegate {
    let model: GridModel

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        model.dragging = nil
        model.persist()
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
