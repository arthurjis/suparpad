import SwiftUI

// M1: alphabetical scrolling grid. Pages (M2) and custom order (M3) come later.
struct LaunchGridView: View {
    let apps: [AppEntry]
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
                    ForEach(apps) { app in
                        AppIconView(app: app) { onLaunch(app) }
                    }
                }
                .padding(.horizontal, 120)
                .padding(.vertical, 80)
            }
        }
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
        Button(action: action) {
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
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
