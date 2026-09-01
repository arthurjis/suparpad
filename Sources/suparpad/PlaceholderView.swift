import SwiftUI

// Placeholder UI: proves the pinch → panel loop. Real grid lands in M1.
struct PlaceholderView: View {
    var body: some View {
        ZStack {
            BlurBackground().ignoresSafeArea()
            Color.black.opacity(0.35).ignoresSafeArea() // dim like real Launchpad
            VStack(spacing: 12) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 64))
                Text("suparpad — summoned by pinch")
                    .font(.system(size: 42, weight: .semibold))
                Text("pinch-open, Esc, or click to dismiss · ⌘Q quits")
                    .font(.title3)
                    .opacity(0.6)
            }
            .foregroundStyle(.white)
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
