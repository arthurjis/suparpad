import AppKit
import SwiftUI

// Placeholder UI: proves the build → run → screenshot loop. Real grid lands in M1.
struct PlaceholderView: View {
    var body: some View {
        ZStack {
            BlurBackground().ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 64))
                Text("suparpad — stack is alive")
                    .font(.system(size: 42, weight: .semibold))
                Text("Esc or ⌘Q to quit")
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

final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: KeyablePanel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let frame = NSScreen.main?.frame ?? .init(x: 0, y: 0, width: 1440, height: 900)
        panel = KeyablePanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: PlaceholderView())
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc
                NSApp.terminate(nil)
                return nil
            }
            return event
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
